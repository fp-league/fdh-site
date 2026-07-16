# Fortnite Drivers Hub — setup

## 1. Create the Supabase project
1. Go to supabase.com → New project (free tier is fine).
2. Once it's ready: **SQL Editor → New query** → paste everything from `schema.sql` → **Run**.

## 2. Connect the site to Supabase
1. In Supabase: **Project Settings → API**.
2. Copy the **Project URL** and the **anon public** key.
3. Open `index.html`, find these two lines near the bottom:
   ```js
   const SUPABASE_URL = 'YOUR_SUPABASE_URL';
   const SUPABASE_ANON_KEY = 'YOUR_SUPABASE_ANON_KEY';
   ```
   Paste your values in.

## 3. Make yourself admin
1. Register a driver account on the live site first (your callsign, email, password).
2. Back in Supabase → SQL Editor, run:
   ```sql
   update profiles set is_admin = true where callsign = 'YOUR_CALLSIGN';
   ```
3. Refresh the site — you'll now see the "Manage promotions" admin panel at the bottom.

## 4. Host it (GitHub Pages, same as FP League)
1. New GitHub repo, e.g. `fortnite-drivers-hub`.
2. Push `index.html` **and the `assets/` folder** (contains `logo.png`) to it — the nav, favicon, and hero all reference `assets/logo.png`, so it needs to sit in the same folder as `index.html`.
3. Repo → Settings → Pages → Deploy from branch → `main` / root.
4. Live at `https://yourusername.github.io/fortnite-drivers-hub/`.

## 5. Discord-role admin access (optional)
Instead of manually flipping `is_admin` in SQL, you can make it automatic: anyone with the admin role in your Discord server gets admin access on the site the next time they log in with Discord.

**A. Discord Developer Portal**
1. discord.com/developers/applications → your bot's app (or a new one) → **OAuth2**.
2. Add redirect URL: `https://<your-supabase-project-ref>.supabase.co/auth/v1/callback`.
3. Copy the **Client ID** and **Client Secret**.

**B. Supabase**
1. **Authentication → Providers → Discord** → enable it, paste the Client ID and Secret.
2. **Project Settings → API** → copy the **service_role** key (different from the anon key — keep this one secret, never put it in `index.html`).

**C. Get your role and server IDs**
1. In Discord, enable Developer Mode (Settings → Advanced).
2. Right-click your server icon → Copy Server ID → this is `DISCORD_GUILD_ID`.
3. Right-click the admin role in Server Settings → Roles → Copy Role ID → this is `ADMIN_ROLE_ID`.
4. Make sure your bot has the **Server Members Intent** enabled (Developer Portal → Bot) and is actually in the server.

**D. Deploy the worker**
```
cd worker
wrangler secret put DISCORD_BOT_TOKEN
wrangler secret put SUPABASE_SERVICE_ROLE_KEY
```
Edit `wrangler.toml` — fill in `DISCORD_GUILD_ID`, `ADMIN_ROLE_ID`, `SUPABASE_URL`, and `ALLOWED_ORIGIN` (your GitHub Pages URL). Then:
```
wrangler deploy
```
Copy the deployed `*.workers.dev` URL into `ADMIN_SYNC_WORKER_URL` near the top of the `<script>` in `index.html`.

**How it behaves:** the first time someone logs in with Discord and has no profile yet, they get a short "finish setup" form (callsign, Epic username, country). After that, every login checks their live Discord role and updates `is_admin` accordingly — so removing the role in Discord removes their site admin access next time they log in too.

**Note:** the field name Supabase uses for the Discord user's snowflake ID in `identities[].identity_data` can vary slightly by provider version. If admin sync isn't picking up correctly, open the browser console after a Discord login, run `await supabase.auth.getSession()`, and check `identities[0].identity_data` to confirm the right field.

## What's in it
- **Public landing page** — hero, driver license card, live league + server promotions side by side.
- **Register/Login** — Supabase Auth (email + password, or Continue with Discord). Registering auto-creates a driver profile with country, next available driver number, and 0 power points.
- **Driver rankings** — top-3 podium plus a top-50 leaderboard, driven by the same power points as the catalogue but shown as a proper leaderboard.
- **Driver catalogue** — public power-rankings table sorted by points, showing position, country, driver number, and licence tier.
- **Awards** — this month's winners across 11 categories (Driver of the Month, Rookie of the Month, Fastest of the Month, etc.), pulled from the Discord server's award structure.
- **League directory** — chip list of every league you track (Formula Nitro, FOA, XFN, FF1, LDC, and the rest — pre-seeded in `schema.sql`, editable from admin).
- **Track reports** — same idea for tracks/servers (Commander, Starworld, Skojs, Timko, Silverarrow, Lux — pre-seeded, editable).
- **Track makers** — directory of the creators/builders behind the maps, each with a copyable map code (feeds off your `mapcodes` channel).
- **Driver stats** — drivers submit their own races/wins/podiums/poles/fastest laps from their dashboard. Nothing shows publicly until an admin approves it from the admin panel; win % is calculated automatically on the public table. Resubmitting sets status back to pending until re-approved.
- **Driver dashboard** — shows your own license card with callsign, licence tier, and driver number once logged in, plus your stats submission form and its approval status.
- **Admin panel** (only visible to accounts with `is_admin = true`) — approve/reject pending stat submissions, add/deactivate league & server promotions, edit any driver's licence tier and power points, set monthly award winners, and manage the league/track directories.

## Notes / things you'll probably want to tweak
- Email confirmation is on by default in Supabase — if you want instant login after registering, turn it off in **Authentication → Providers → Email → Confirm email**.
- Driver numbers are assigned sequentially (#001, #002...) based on registration order.
- Tiers are hardcoded as `rookie / racer / pro / elite` — easy to rename in the `<select>` in `index.html` and the check constraint isn't enforced, so you can add more anytime.
