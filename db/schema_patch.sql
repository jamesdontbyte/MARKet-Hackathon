-- MARKet schema patch (safe to re-run). Run in the Supabase SQL editor, AFTER db/schema.sql and db/seed.sql.
-- Fixes: voucher double-redeem exploit, non-atomic redemption, unverified businesses visible,
-- storage upsert failure.

-- 1. Redemptions: shoppers may read and issue their own voucher, but never update/delete it.
--    (Old policy was FOR ALL: a shopper could set status back to 'issued' and redeem twice.)
drop policy if exists "shopper own redemptions" on redemptions;
drop policy if exists "merchant manages redemptions" on redemptions;

drop policy if exists "shopper reads own redemptions" on redemptions;
create policy "shopper reads own redemptions" on redemptions for select to authenticated
  using (user_id = auth.uid());

drop policy if exists "shopper issues own voucher" on redemptions;
create policy "shopper issues own voucher" on redemptions for insert to authenticated
  with check (user_id = auth.uid() and status = 'issued' and redeemed_at is null);

-- Merchants may only READ vouchers for their own promos (scan preview). Redeeming goes through the RPC below.
drop policy if exists "merchant reads own redemptions" on redemptions;
create policy "merchant reads own redemptions" on redemptions for select to authenticated
  using (exists (select 1 from promos p join businesses b on b.id = p.business_id
                 where p.id = redemptions.promo_id and b.owner_id = auth.uid()));

-- 2. Atomic redeem: one call checks ownership, status, dates and limit, then updates both tables.
create or replace function redeem_voucher(p_code text)
returns text
language plpgsql
security definer
set search_path = public
as $$
declare
  r redemptions;
  p promos;
begin
  select * into r from redemptions where code = upper(trim(p_code)) for update;
  if not found then return 'invalid'; end if;

  select * into p from promos where id = r.promo_id for update;

  if not exists (select 1 from businesses b where b.id = p.business_id and b.owner_id = auth.uid()) then
    return 'not_your_promo';
  end if;
  if r.status = 'redeemed' then return 'already_redeemed'; end if;
  if not p.active or now() < p.starts_at or now() > p.ends_at then return 'expired'; end if;
  if p.redeemed_count >= p.redeem_limit then return 'limit_reached'; end if;

  update redemptions set status = 'redeemed', redeemed_at = now() where id = r.id;
  update promos set redeemed_count = redeemed_count + 1 where id = p.id;
  insert into geofence_events (user_id, business_id, promo_id, event_type)
    values (r.user_id, p.business_id, p.id, 'redeemed');

  return 'ok';
end;
$$;

revoke all on function redeem_voucher(text) from public;
grant execute on function redeem_voucher(text) to authenticated;
-- App usage: final res = await supabase.rpc('redeem_voucher', params: {'p_code': code});
-- res is one of: ok | invalid | not_your_promo | already_redeemed | expired | limit_reached

-- 3. Shoppers should only see verified businesses (and their promos/products). Owners still see their own.
drop policy if exists "read businesses" on businesses;
drop policy if exists "read verified or own businesses" on businesses;
create policy "read verified or own businesses" on businesses for select to authenticated
  using (verified or owner_id = auth.uid());

drop policy if exists "read promos" on promos;
drop policy if exists "read promos of visible businesses" on promos;
create policy "read promos of visible businesses" on promos for select to authenticated
  using (exists (select 1 from businesses b
                 where b.id = promos.business_id and (b.verified or b.owner_id = auth.uid())));

drop policy if exists "read products" on products;
drop policy if exists "read products of visible businesses" on products;
create policy "read products of visible businesses" on products for select to authenticated
  using (exists (select 1 from businesses b
                 where b.id = products.business_id and (b.verified or b.owner_id = auth.uid())));

-- 4. Storage: allow re-upload (upsert) of a user's own documents.
drop policy if exists "update own docs" on storage.objects;
create policy "update own docs" on storage.objects for update to authenticated
  using (bucket_id = 'merchant-docs' and (storage.foldername(name))[1] = auth.uid()::text);

-- 5. Businesses: add cover_url column
alter table businesses add column if not exists cover_url text;
