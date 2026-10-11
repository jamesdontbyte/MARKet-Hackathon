-- MARKet schema (Supabase / Postgres). Run once in the SQL editor.

create table if not exists profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  role text not null check (role in ('shopper','merchant')),
  full_name text,
  phone text,
  interests text[] not null default '{}',
  prefs jsonb not null default '{"flash_promos":true,"expiry_reminders":true,"weekly_digest":false}',
  created_at timestamptz not null default now()
);

create table if not exists businesses (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid references profiles(id) on delete cascade,   -- null for seed data
  name text not null,
  category text not null check (category in ('food','cafe','salon','retail','grocery','wellness','services','travel')),
  subtitle text,
  bio text,
  address text,
  phone text,
  hours text,
  lat double precision not null,
  lng double precision not null,
  radius_m double precision not null default 1500,
  rating numeric(2,1) default 4.5,
  verified boolean not null default false,
  created_at timestamptz not null default now()
);

create table if not exists products (
  id uuid primary key default gen_random_uuid(),
  business_id uuid not null references businesses(id) on delete cascade,
  name text not null,
  price numeric(10,2) not null default 0,
  category text,
  description text,
  created_at timestamptz not null default now()
);

create table if not exists promos (
  id uuid primary key default gen_random_uuid(),
  business_id uuid not null references businesses(id) on delete cascade,
  title text not null,
  description text,
  promo_type text not null default 'percent' check (promo_type in ('bogo','percent','amount_off')),
  value_label text,                       -- e.g. 'BOGO', '20% OFF', '₱100 OFF'
  starts_at timestamptz not null default now(),
  ends_at timestamptz not null default (now() + interval '7 days'),
  redeem_limit int not null default 100,
  redeemed_count int not null default 0,
  active boolean not null default true,
  created_at timestamptz not null default now()
);

create table if not exists stash (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references profiles(id) on delete cascade,
  promo_id uuid not null references promos(id) on delete cascade,
  saved_at timestamptz not null default now(),
  unique (user_id, promo_id)
);

create table if not exists redemptions (
  id uuid primary key default gen_random_uuid(),
  promo_id uuid not null references promos(id) on delete cascade,
  user_id uuid not null references profiles(id) on delete cascade,
  code text not null unique,
  status text not null default 'issued' check (status in ('issued','redeemed')),
  created_at timestamptz not null default now(),
  redeemed_at timestamptz,
  unique (user_id, promo_id)
);

create table if not exists geofence_events (
  id bigserial primary key,
  user_id uuid references profiles(id) on delete set null,
  business_id uuid references businesses(id) on delete cascade,  -- nullable: zone-level ping
  promo_id uuid references promos(id) on delete set null,
  event_type text not null check (event_type in ('ping_sent','opened','viewed','claimed','redeemed')),
  created_at timestamptz not null default now()
);

create index if not exists idx_promos_business on promos(business_id);
create index if not exists idx_events_business_time on geofence_events(business_id, created_at);

-- ---------- Row Level Security ----------
alter table profiles enable row level security;
alter table businesses enable row level security;
alter table products enable row level security;
alter table promos enable row level security;
alter table stash enable row level security;
alter table redemptions enable row level security;
alter table geofence_events enable row level security;

create policy "own profile" on profiles for all to authenticated
  using (id = auth.uid()) with check (id = auth.uid());

create policy "read businesses" on businesses for select to authenticated using (true);
create policy "owner inserts business" on businesses for insert to authenticated
  with check (owner_id = auth.uid());
-- DEMO: owner may update own row (needed for the auto-verify timer).
create policy "owner updates business" on businesses for update to authenticated
  using (owner_id = auth.uid()) with check (owner_id = auth.uid());

create policy "read products" on products for select to authenticated using (true);
create policy "owner writes products" on products for all to authenticated
  using (exists (select 1 from businesses b where b.id = products.business_id and b.owner_id = auth.uid()))
  with check (exists (select 1 from businesses b where b.id = products.business_id and b.owner_id = auth.uid()));

create policy "read promos" on promos for select to authenticated using (true);
create policy "owner writes promos" on promos for all to authenticated
  using (exists (select 1 from businesses b where b.id = promos.business_id and b.owner_id = auth.uid()))
  with check (exists (select 1 from businesses b where b.id = promos.business_id and b.owner_id = auth.uid()));

create policy "own stash" on stash for all to authenticated
  using (user_id = auth.uid()) with check (user_id = auth.uid());

create policy "shopper own redemptions" on redemptions for all to authenticated
  using (user_id = auth.uid()) with check (user_id = auth.uid());
create policy "merchant manages redemptions" on redemptions for all to authenticated
  using (exists (select 1 from promos p join businesses b on b.id = p.business_id
                 where p.id = redemptions.promo_id and b.owner_id = auth.uid()))
  with check (exists (select 1 from promos p join businesses b on b.id = p.business_id
                 where p.id = redemptions.promo_id and b.owner_id = auth.uid()));

create policy "insert own events" on geofence_events for insert to authenticated
  with check (user_id = auth.uid());
create policy "read own or business events" on geofence_events for select to authenticated
  using (user_id = auth.uid()
         or exists (select 1 from businesses b where b.id = geofence_events.business_id and b.owner_id = auth.uid()));

-- ---------- Storage (private bucket for merchant/shopper documents) ----------
insert into storage.buckets (id, name, public) values ('merchant-docs','merchant-docs', false)
  on conflict (id) do nothing;
create policy "upload own docs" on storage.objects for insert to authenticated
  with check (bucket_id = 'merchant-docs' and (storage.foldername(name))[1] = auth.uid()::text);
create policy "read own docs" on storage.objects for select to authenticated
  using (bucket_id = 'merchant-docs' and (storage.foldername(name))[1] = auth.uid()::text);
