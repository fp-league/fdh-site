-- ============================================================
-- Fortnite Drivers Hub — Supabase Schema
-- Run this in Supabase: Project → SQL Editor → New query → paste → Run
-- ============================================================

-- 1. DRIVER PROFILES
-- One row per registered driver, linked to Supabase Auth user
create table if not exists profiles (
  id uuid references auth.users on delete cascade primary key,
  callsign text unique not null,
  epic_username text not null,
  driver_number int unique,
  country text default '',
  tier text not null default 'rookie', -- licence tier: rookie | racer | pro | elite
  power_points int not null default 0,
  is_admin boolean not null default false,
  discord_id text unique,
  created_at timestamptz not null default now()
);

alter table profiles enable row level security;

drop policy if exists "Profiles are publicly readable" on profiles;
create policy "Profiles are publicly readable"
  on profiles for select
  using (true);

drop policy if exists "Users can insert their own profile" on profiles;
create policy "Users can insert their own profile"
  on profiles for insert
  with check (auth.uid() = id);

drop policy if exists "Users can update their own profile" on profiles;
create policy "Users can update their own profile"
  on profiles for update
  using (auth.uid() = id);

drop policy if exists "Admins can update any profile" on profiles;
create policy "Admins can update any profile"
  on profiles for update
  using (exists (select 1 from profiles p where p.id = auth.uid() and p.is_admin = true));


-- 2. PROMOTIONS (league or server)
create table if not exists promotions (
  id uuid primary key default gen_random_uuid(),
  type text not null check (type in ('league', 'server')),
  title text not null,
  description text,
  active boolean not null default true,
  starts_at timestamptz default now(),
  ends_at timestamptz,
  created_at timestamptz not null default now()
);

alter table promotions enable row level security;

drop policy if exists "Active promotions are publicly readable" on promotions;
create policy "Active promotions are publicly readable"
  on promotions for select
  using (active = true);

drop policy if exists "Admins manage promotions" on promotions;
create policy "Admins manage promotions"
  on promotions for all
  using (exists (select 1 from profiles p where p.id = auth.uid() and p.is_admin = true));


-- 3. LEAGUES (league directory)
create table if not exists leagues (
  id uuid primary key default gen_random_uuid(),
  name text unique not null,
  active boolean not null default true,
  created_at timestamptz not null default now()
);

alter table leagues enable row level security;

drop policy if exists "Leagues are publicly readable" on leagues;
create policy "Leagues are publicly readable"
  on leagues for select
  using (true);

drop policy if exists "Admins manage leagues" on leagues;
create policy "Admins manage leagues"
  on leagues for all
  using (exists (select 1 from profiles p where p.id = auth.uid() and p.is_admin = true));

insert into leagues (name) values
  ('Formula Nitro'), ('Formula Fortnite'), ('FOA'), ('XFN'), ('FF1'), ('LDC'),
  ('CPFN'), ('FES'), ('Geo Racing'), ('FTS'), ('FN1'), ('FGE'), ('PFFA'),
  ('CC'), ('FFL'), ('FRA'), ('FCFL'), ('Apex Racing'), ('IGTC'), ('GFN'), ('INDYFN')
on conflict (name) do nothing;


-- 4. TRACKS (track reports directory)
create table if not exists tracks (
  id uuid primary key default gen_random_uuid(),
  name text unique not null,
  active boolean not null default true,
  created_at timestamptz not null default now()
);

alter table tracks enable row level security;

drop policy if exists "Tracks are publicly readable" on tracks;
create policy "Tracks are publicly readable"
  on tracks for select
  using (true);

drop policy if exists "Admins manage tracks" on tracks;
create policy "Admins manage tracks"
  on tracks for all
  using (exists (select 1 from profiles p where p.id = auth.uid() and p.is_admin = true));

insert into tracks (name) values
  ('Commander'), ('Starworld'), ('Skojs'), ('Timko'), ('Silverarrow'), ('Lux')
on conflict (name) do nothing;


-- 5. AWARDS (monthly awards)
create table if not exists awards (
  id uuid primary key default gen_random_uuid(),
  category text not null, -- e.g. 'Driver of the Month', 'Rookie of the Month'
  month text not null,    -- e.g. '2026-07'
  winner_callsign text,
  created_at timestamptz not null default now(),
  unique (category, month)
);

alter table awards enable row level security;

drop policy if exists "Awards are publicly readable" on awards;
create policy "Awards are publicly readable"
  on awards for select
  using (true);

drop policy if exists "Admins manage awards" on awards;
create policy "Admins manage awards"
  on awards for all
  using (exists (select 1 from profiles p where p.id = auth.uid() and p.is_admin = true));


-- 6. DRIVER STATS (self-submitted, admin-approved)
create table if not exists driver_stats (
  id uuid references profiles(id) on delete cascade primary key,
  races int not null default 0,
  wins int not null default 0,
  podiums int not null default 0,
  poles int not null default 0,
  fastest_laps int not null default 0,
  status text not null default 'pending' check (status in ('pending','approved','rejected')),
  submitted_at timestamptz not null default now(),
  reviewed_at timestamptz
);

alter table driver_stats enable row level security;

drop policy if exists "Approved stats are publicly readable" on driver_stats;
create policy "Approved stats are publicly readable"
  on driver_stats for select
  using (status = 'approved');

drop policy if exists "Drivers can view their own stats regardless of status" on driver_stats;
create policy "Drivers can view their own stats regardless of status"
  on driver_stats for select
  using (auth.uid() = id);

drop policy if exists "Drivers can submit their own stats for review" on driver_stats;
create policy "Drivers can submit their own stats for review"
  on driver_stats for insert
  with check (auth.uid() = id and status = 'pending');

drop policy if exists "Drivers can resubmit their own stats for review" on driver_stats;
create policy "Drivers can resubmit their own stats for review"
  on driver_stats for update
  using (auth.uid() = id)
  with check (auth.uid() = id and status = 'pending');

drop policy if exists "Admins manage all driver stats" on driver_stats;
create policy "Admins manage all driver stats"
  on driver_stats for all
  using (exists (select 1 from profiles p where p.id = auth.uid() and p.is_admin = true));


-- 7. TRACK MAKERS (map/track creators directory)
create table if not exists track_makers (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  epic_username text,
  map_code text,
  active boolean not null default true,
  created_at timestamptz not null default now()
);

alter table track_makers enable row level security;

drop policy if exists "Track makers are publicly readable" on track_makers;
create policy "Track makers are publicly readable"
  on track_makers for select
  using (true);

drop policy if exists "Admins manage track makers" on track_makers;
create policy "Admins manage track makers"
  on track_makers for all
  using (exists (select 1 from profiles p where p.id = auth.uid() and p.is_admin = true));


-- ============================================================
-- After running this:
-- 1. Go to Authentication → Providers → make sure Email is enabled
-- 2. Register your own account on the site first
-- 3. Come back here and run this to make yourself admin:
--    update profiles set is_admin = true where callsign = 'YOUR_CALLSIGN';
-- ============================================================
