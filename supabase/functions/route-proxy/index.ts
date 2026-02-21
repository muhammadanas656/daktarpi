const defaultHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
};

type RoutePoint = { lat: number; lng: number };
type UpstreamRequest = { url: string; headers?: Record<string, string> };
type RateLimitState = {
  count: number;
  resetAt: number;
  blockedUntil: number;
};

const rateLimitWindowMs = Math.max(
  1_000,
  Number(Deno.env.get("RATE_LIMIT_WINDOW_MS") ?? 60_000),
);
const rateLimitMaxRequests = Math.max(
  1,
  Number(Deno.env.get("RATE_LIMIT_MAX_REQUESTS") ?? 60),
);
const rateLimitBlockMs = Math.max(
  rateLimitWindowMs,
  Number(Deno.env.get("RATE_LIMIT_BLOCK_MS") ?? 120_000),
);
const upstreamTimeoutMs = Math.max(
  1_000,
  Number(Deno.env.get("ROUTE_PROXY_TIMEOUT_MS") ?? 8_000),
);

const rateLimitStore = new Map<string, RateLimitState>();

function asNumber(value: unknown): number | null {
  if (typeof value === "number" && Number.isFinite(value)) return value;
  if (typeof value === "string") {
    const parsed = Number(value);
    return Number.isFinite(parsed) ? parsed : null;
  }
  return null;
}

function parsePoint(input: unknown): RoutePoint | null {
  if (!input || typeof input !== "object") return null;
  const data = input as Record<string, unknown>;
  const lat = asNumber(data.lat);
  const lng = asNumber(data.lng);
  if (lat == null || lng == null) return null;
  if (lat < -90 || lat > 90 || lng < -180 || lng > 180) {
    return null;
  }
  return { lat, lng };
}

function jsonResponse(
  body: unknown,
  status: number,
  extraHeaders: Record<string, string> = {},
) {
  return new Response(JSON.stringify(body), {
    status,
    headers: {
      ...defaultHeaders,
      "Content-Type": "application/json",
      ...extraHeaders,
    },
  });
}

function extractClientKey(req: Request): string {
  const forwardedFor = req.headers.get("x-forwarded-for");
  const ipFromForwarded = forwardedFor?.split(",")[0]?.trim();
  const ip =
    ipFromForwarded ||
    req.headers.get("cf-connecting-ip") ||
    req.headers.get("x-real-ip");
  if (ip && ip.length > 0) {
    return `ip:${ip}`;
  }

  const auth = req.headers.get("authorization");
  if (auth && auth.length > 0) {
    return `auth:${auth.slice(0, 64)}`;
  }

  const fallback = req.headers.get("user-agent") ?? "unknown-client";
  return `ua:${fallback.slice(0, 64)}`;
}

function sweepExpiredRateLimitEntries(now: number) {
  for (const [key, state] of rateLimitStore.entries()) {
    if (state.blockedUntil <= now && state.resetAt <= now) {
      rateLimitStore.delete(key);
    }
  }
}

function enforceRateLimit(req: Request): Response | null {
  const now = Date.now();
  sweepExpiredRateLimitEntries(now);

  const clientKey = extractClientKey(req);
  const existing = rateLimitStore.get(clientKey);
  const current: RateLimitState =
    existing && existing.resetAt > now
      ? existing
      : { count: 0, resetAt: now + rateLimitWindowMs, blockedUntil: 0 };

  if (current.blockedUntil > now) {
    const retryAfterSeconds = Math.max(
      1,
      Math.ceil((current.blockedUntil - now) / 1_000),
    );
    return jsonResponse(
      {
        error: "Too many requests",
        detail: "Rate limit exceeded for route-proxy.",
      },
      429,
      {
        "Retry-After": String(retryAfterSeconds),
        "X-RateLimit-Limit": String(rateLimitMaxRequests),
        "X-RateLimit-Remaining": "0",
        "X-RateLimit-Reset": String(Math.floor(current.resetAt / 1_000)),
      },
    );
  }

  current.count += 1;
  if (current.count > rateLimitMaxRequests) {
    current.blockedUntil = now + rateLimitBlockMs;
    rateLimitStore.set(clientKey, current);

    const retryAfterSeconds = Math.max(
      1,
      Math.ceil((current.blockedUntil - now) / 1_000),
    );
    return jsonResponse(
      {
        error: "Too many requests",
        detail: "Rate limit exceeded for route-proxy.",
      },
      429,
      {
        "Retry-After": String(retryAfterSeconds),
        "X-RateLimit-Limit": String(rateLimitMaxRequests),
        "X-RateLimit-Remaining": "0",
        "X-RateLimit-Reset": String(Math.floor(current.resetAt / 1_000)),
      },
    );
  }

  rateLimitStore.set(clientKey, current);
  return null;
}

function resolveUpstreamRequest(start: RoutePoint, end: RoutePoint): UpstreamRequest {
  const provider = (Deno.env.get("ROUTE_PROVIDER") ?? "osrm").toLowerCase();

  if (provider === "mapbox") {
    const accessToken = Deno.env.get("MAPBOX_ACCESS_TOKEN");
    if (!accessToken) {
      throw new Error("MAPBOX_ACCESS_TOKEN is required when ROUTE_PROVIDER=mapbox");
    }
    const base =
      Deno.env.get("MAPBOX_BASE_URL") ??
      "https://api.mapbox.com/directions/v5/mapbox";
    const url =
      `${base}/driving/${start.lng},${start.lat};${end.lng},${end.lat}` +
      `?overview=full&geometries=geojson&access_token=${encodeURIComponent(accessToken)}`;

    return { url, headers: { Accept: "application/json" } };
  }

  const osrmBase =
    Deno.env.get("OSRM_BASE_URL") ?? "https://router.project-osrm.org";
  const url =
    `${osrmBase}/route/v1/driving/${start.lng},${start.lat};${end.lng},${end.lat}` +
    "?overview=full&geometries=geojson";

  return { url, headers: { Accept: "application/json" } };
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: defaultHeaders });
  }

  try {
    if (req.method !== "POST") {
      return jsonResponse({ error: "Method not allowed" }, 405);
    }

    const rateLimitViolation = enforceRateLimit(req);
    if (rateLimitViolation != null) {
      return rateLimitViolation;
    }

    const body = await req.json();
    const start = parsePoint(body?.start);
    const end = parsePoint(body?.end);

    if (!start || !end) {
      return jsonResponse(
        { error: "Invalid request body. Expected start/end lat/lng values." },
        400,
      );
    }

    const upstreamRequest = resolveUpstreamRequest(start, end);
    const controller = new AbortController();
    const timeoutHandle = setTimeout(() => controller.abort(), upstreamTimeoutMs);

    try {
      const upstream = await fetch(upstreamRequest.url, {
        method: "GET",
        headers: upstreamRequest.headers ?? { Accept: "application/json" },
        signal: controller.signal,
      });
      const payload = await upstream.text();
      return new Response(payload, {
        status: upstream.status,
        headers: { ...defaultHeaders, "Content-Type": "application/json" },
      });
    } finally {
      clearTimeout(timeoutHandle);
    }
  } catch (error) {
    return jsonResponse(
      { error: "route-proxy failure", detail: String(error) },
      500,
    );
  }
});
