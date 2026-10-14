-- MARKet schema patch: Business Media & Structured Operating Hours
-- DO NOT APPLY AUTOMATICALLY: Run manually in the Supabase SQL Editor if applying to the database.

-- 1. Add media and structured hours columns to businesses table
alter table businesses add column if not exists logo_url text;
alter table businesses add column if not exists interior_urls text[] default '{}';
alter table businesses add column if not exists open_days text[] default array['Mon','Tue','Wed','Thu','Fri','Sat','Sun'];
alter table businesses add column if not exists opens_at text default '07:30';
alter table businesses add column if not exists closes_at text default '21:00';

-- (cover_url text was already added in schema_patch.sql; added here with if not exists for safety)
alter table businesses add column if not exists cover_url text;

-- 2. Create public-read storage bucket 'business-media'
insert into storage.buckets (id, name, public)
values ('business-media', 'business-media', true)
on conflict (id) do update set public = true;

-- 3. Storage policies for 'business-media' bucket
-- Public read access: anyone can view merchant logos, storefront exterior and interior photos
drop policy if exists "public read business media" on storage.objects;
create policy "public read business media" on storage.objects for select to public
  using (bucket_id = 'business-media');

-- Owner upload access: authenticated merchant can upload files only inside <their uid>/
drop policy if exists "owner uploads business media" on storage.objects;
create policy "owner uploads business media" on storage.objects for insert to authenticated
  with check (bucket_id = 'business-media' and (storage.foldername(name))[1] = auth.uid()::text);

-- Owner update/upsert access: authenticated merchant can overwrite files inside <their uid>/
drop policy if exists "owner updates business media" on storage.objects;
create policy "owner updates business media" on storage.objects for update to authenticated
  using (bucket_id = 'business-media' and (storage.foldername(name))[1] = auth.uid()::text);

-- Owner delete access: authenticated merchant can delete files inside <their uid>/
drop policy if exists "owner deletes business media" on storage.objects;
create policy "owner deletes business media" on storage.objects for delete to authenticated
  using (bucket_id = 'business-media' and (storage.foldername(name))[1] = auth.uid()::text);

-- 4. Add product image, status, and best-seller columns to products table
alter table products add column if not exists image_url text;
alter table products add column if not exists description text;
alter table products add column if not exists is_best_seller boolean not null default false;
alter table products add column if not exists available boolean not null default true;

-- 5. Add optional linked product to promos table
alter table promos add column if not exists product_id uuid references products(id) on delete set null;


-- 6. Add promo image column to promos table (nullable text, existing promos remain valid)
alter table promos add column if not exists image_url text;

-- 7. Add stock photo attribution and source columns to products table
-- image_source: 'own', 'stock', 'ai', or null when no photo
-- image_credit: photographer name / attribution text
-- image_credit_url: photo page URL / source URL
-- Existing rows remain valid as all three columns are nullable with no default constraint breaking existing records.
alter table products add column if not exists image_source text check (image_source in ('own', 'stock', 'ai'));
alter table products add column if not exists image_credit text;
alter table products add column if not exists image_credit_url text;

-- 8. 24-hour stock photo search cache for Pixabay suggestions
-- query: normalized clean English search query (primary key)
-- results: JSONB array of candidate photo objects (same shape as Edge Function response)
-- expires_at: timestamp when the cache entry expires (now() + interval '24 hours')
-- RLS enabled with NO client access: anon and authenticated roles have no SELECT/INSERT/UPDATE/DELETE.
-- Only the Edge Function using the Supabase service_role key can read or write to this table.
create table if not exists search_cache (
  query text primary key,
  results jsonb not null,
  expires_at timestamptz not null
);

alter table search_cache enable row level security;
-- Default deny applies to all client roles. No client policies created.
