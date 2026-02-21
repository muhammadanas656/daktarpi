const defaultHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
};

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

    const payload = await req.json();
    console.log("client-error-log:", payload);

    return new Response(JSON.stringify({ ok: true }), {
      status: 200,
      headers: { ...defaultHeaders, "Content-Type": "application/json" },
    });
  } catch (error) {
    return new Response(
      JSON.stringify({ error: "client-error-log failure", detail: String(error) }),
      {
        status: 500,
        headers: { ...defaultHeaders, "Content-Type": "application/json" },
      },
    );
  }
});
