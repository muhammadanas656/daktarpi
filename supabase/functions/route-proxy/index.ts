const defaultHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
};

type RoutePoint = { lat: number; lng: number };

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
  return { lat, lng };
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: defaultHeaders });
  }

  try {
    if (req.method !== "POST") {
      return new Response(JSON.stringify({ error: "Method not allowed" }), {
        status: 405,
        headers: { ...defaultHeaders, "Content-Type": "application/json" },
      });
    }

    const body = await req.json();
    const start = parsePoint(body?.start);
    const end = parsePoint(body?.end);

    if (!start || !end) {
      return new Response(
        JSON.stringify({
          error: "Invalid request body. Expected start/end lat/lng values.",
        }),
        {
          status: 400,
          headers: { ...defaultHeaders, "Content-Type": "application/json" },
        },
      );
    }

    const osrmBase =
      Deno.env.get("OSRM_BASE_URL") ?? "https://router.project-osrm.org";
    const url =
      `${osrmBase}/route/v1/driving/${start.lng},${start.lat};${end.lng},${end.lat}` +
      "?overview=full&geometries=geojson";

    const upstream = await fetch(url, {
      method: "GET",
      headers: { Accept: "application/json" },
    });

    const payload = await upstream.text();
    return new Response(payload, {
      status: upstream.status,
      headers: { ...defaultHeaders, "Content-Type": "application/json" },
    });
  } catch (error) {
    return new Response(
      JSON.stringify({ error: "route-proxy failure", detail: String(error) }),
      {
        status: 500,
        headers: { ...defaultHeaders, "Content-Type": "application/json" },
      },
    );
  }
});
