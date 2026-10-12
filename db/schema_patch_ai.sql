-- MARKet schema patch: In-App AI Assistant Usage & Rate Limiting
-- DO NOT APPLY AUTOMATICALLY: Run manually in the Supabase SQL Editor if applying to the database.

-- 1. Create table for tracking AI requests per authenticated user
create table if not exists ai_usage (
  id bigserial primary key,
  user_id uuid not null references auth.users(id) on delete cascade default auth.uid(),
  created_at timestamptz not null default now()
);

-- 2. Index for efficient hourly usage queries per user
create index if not exists idx_ai_usage_user_created
  on ai_usage(user_id, created_at desc);

-- 3. Enable Row Level Security
alter table ai_usage enable row level security;

-- 4. RLS Policies: Authenticated users can only insert and read their own rows
-- Evaluated against caller's JWT (auth.uid()), never requiring a service-role key
drop policy if exists "users read own ai_usage" on ai_usage;
create policy "users read own ai_usage" on ai_usage
  for select to authenticated
  using (user_id = auth.uid());

drop policy if exists "users insert own ai_usage" on ai_usage;
create policy "users insert own ai_usage" on ai_usage
  for insert to authenticated
  with check (user_id = auth.uid());
