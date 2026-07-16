/**
 * Fortnite Drivers Hub — Admin Sync Worker
 *
 * Checks whether a Discord user currently holds the admin role in your
 * server, then writes that result to their `profiles.is_admin` row in
 * Supabase using the service role key (bypasses RLS — keep this secret!).
 *
 * Deploy with wrangler, set these secrets first:
 *   wrangler secret put DISCORD_BOT_TOKEN
 *   wrangler secret put SUPABASE_SERVICE_ROLE_KEY
 * And these plain vars in wrangler.toml:
 *   DISCORD_GUILD_ID, ADMIN_ROLE_ID, SUPABASE_URL, ALLOWED_ORIGIN
 */

function corsHeaders(origin) {
  return {
    "Access-Control-Allow-Origin": origin,
    "Access-Control-Allow-Methods": "POST, OPTIONS",
    "Access-Control-Allow-Headers": "Content-Type",
  };
}

export default {
  async fetch(request, env) {
    const origin = env.ALLOWED_ORIGIN || "*";

    if (request.method === "OPTIONS") {
      return new Response(null, { headers: corsHeaders(origin) });
    }

    if (request.method !== "POST") {
      return new Response("Method not allowed", { status: 405, headers: corsHeaders(origin) });
    }

    let body;
    try {
      body = await request.json();
    } catch {
      return new Response(JSON.stringify({ error: "Invalid JSON" }), {
        status: 400, headers: { "Content-Type": "application/json", ...corsHeaders(origin) },
      });
    }

    const discordId = body.discord_id;
    if (!discordId) {
      return new Response(JSON.stringify({ error: "discord_id required" }), {
        status: 400, headers: { "Content-Type": "application/json", ...corsHeaders(origin) },
      });
    }

    // 1. Look up the member's roles in your Discord server via the bot
    let isAdmin = false;
    const memberRes = await fetch(
      `https://discord.com/api/v10/guilds/${env.DISCORD_GUILD_ID}/members/${discordId}`,
      { headers: { Authorization: `Bot ${env.DISCORD_BOT_TOKEN}` } }
    );

    if (memberRes.status === 200) {
      const member = await memberRes.json();
      isAdmin = Array.isArray(member.roles) && member.roles.includes(env.ADMIN_ROLE_ID);
    } else if (memberRes.status !== 404) {
      // Something other than "not in guild" went wrong — don't silently deny
      const errText = await memberRes.text();
      return new Response(JSON.stringify({ error: "Discord lookup failed", detail: errText }), {
        status: 502, headers: { "Content-Type": "application/json", ...corsHeaders(origin) },
      });
    }
    // 404 = not a member of the guild -> isAdmin stays false

    // 2. Write the result to Supabase (service role key bypasses RLS)
    const updateRes = await fetch(
      `${env.SUPABASE_URL}/rest/v1/profiles?discord_id=eq.${encodeURIComponent(discordId)}`,
      {
        method: "PATCH",
        headers: {
          "Content-Type": "application/json",
          apikey: env.SUPABASE_SERVICE_ROLE_KEY,
          Authorization: `Bearer ${env.SUPABASE_SERVICE_ROLE_KEY}`,
          Prefer: "return=representation",
        },
        body: JSON.stringify({ is_admin: isAdmin }),
      }
    );

    if (!updateRes.ok) {
      const errText = await updateRes.text();
      return new Response(JSON.stringify({ error: "Supabase update failed", detail: errText }), {
        status: 502, headers: { "Content-Type": "application/json", ...corsHeaders(origin) },
      });
    }

    return new Response(JSON.stringify({ isAdmin }), {
      status: 200, headers: { "Content-Type": "application/json", ...corsHeaders(origin) },
    });
  },
};
