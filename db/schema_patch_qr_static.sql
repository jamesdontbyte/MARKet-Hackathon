-- MARKet Redemption Flow v2: Static Store QR Code & Server Validation Patch
-- NOTE: Do NOT apply automatically. Run manually in Supabase SQL Editor if desired.

-- 1. Table for Static Promo Store Codes
-- Stored in a dedicated table with Row Level Security enabled.
-- No client policies for 'anon' or 'authenticated' roles: shoppers cannot read this table directly.
create table if not exists promo_store_codes (
  promo_id uuid primary key references promos(id) on delete cascade,
  store_code text not null unique,
  created_at timestamptz default now(),
  updated_at timestamptz default now()
);

alter table promo_store_codes enable row level security;
-- Shoppers cannot query promo_store_codes. Access is strictly granted via SECURITY DEFINER functions.

-- 2. Generator function for unique 8-character alphanumeric code
create or replace function generate_unique_store_code()
returns text
language plpgsql
as $$
declare
  v_chars text := '23456789ABCDEFGHJKLMNPQRSTUVWXYZ';
  v_code text := '';
  i int;
begin
  loop
    v_code := '';
    for i in 1..8 loop
      v_code := v_code || substr(v_chars, floor(random() * length(v_chars) + 1)::int, 1);
    end loop;
    if not exists (select 1 from promo_store_codes where store_code = v_code) then
      return v_code;
    end if;
  end loop;
end;
$$;

-- Pre-seed codes for existing promotions if not yet populated
insert into promo_store_codes (promo_id, store_code)
select id, upper(substring(md5(id::text || ':' || random()::text) from 1 for 8))
from promos
on conflict (promo_id) do nothing;

-- 3. get_store_code(p_promo_id uuid)
-- Callable ONLY by the owner of that promo's business.
-- Returns the permanent static 8-character code and QR payload.
create or replace function get_store_code(p_promo_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_promo promos%rowtype;
  v_biz businesses%rowtype;
  v_code text;
  v_qr_payload text;
begin
  if auth.uid() is null then
    raise exception 'Not authenticated';
  end if;

  select * into v_promo from promos where id = p_promo_id;
  if not found then
    raise exception 'Promo not found';
  end if;

  select * into v_biz from businesses where id = v_promo.business_id;
  if not found or v_biz.owner_id is distinct from auth.uid() then
    raise exception 'Unauthorized: caller does not own this promo business';
  end if;

  -- Fetch existing static code or generate and assign one permanently
  select store_code into v_code from promo_store_codes where promo_id = p_promo_id;
  if v_code is null then
    v_code := generate_unique_store_code();
    insert into promo_store_codes (promo_id, store_code, updated_at)
    values (p_promo_id, v_code, now())
    on conflict (promo_id) do update set updated_at = now()
    returning store_code into v_code;
  end if;

  v_qr_payload := json_build_object(
    'app', 'market',
    'code', v_code,
    'promo_id', v_promo.id,
    'business_id', v_biz.id
  )::text;

  return jsonb_build_object(
    'code', v_code,
    'qr_payload', v_qr_payload,
    'promo_id', v_promo.id,
    'business_id', v_biz.id
  );
end;
$$;

revoke all on function get_store_code(uuid) from public;
grant execute on function get_store_code(uuid) to authenticated;

-- 4. reset_store_code(p_promo_id uuid)
-- Callable ONLY by the owner of that promo's business.
-- Generates a new unique static code and invalidates the previous one immediately.
create or replace function reset_store_code(p_promo_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_promo promos%rowtype;
  v_biz businesses%rowtype;
  v_new_code text;
  v_qr_payload text;
begin
  if auth.uid() is null then
    raise exception 'Not authenticated';
  end if;

  select * into v_promo from promos where id = p_promo_id;
  if not found then
    raise exception 'Promo not found';
  end if;

  select * into v_biz from businesses where id = v_promo.business_id;
  if not found or v_biz.owner_id is distinct from auth.uid() then
    raise exception 'Unauthorized: caller does not own this promo business';
  end if;

  v_new_code := generate_unique_store_code();

  insert into promo_store_codes (promo_id, store_code, updated_at)
  values (p_promo_id, v_new_code, now())
  on conflict (promo_id) do update
  set store_code = v_new_code, updated_at = now();

  v_qr_payload := json_build_object(
    'app', 'market',
    'code', v_new_code,
    'promo_id', v_promo.id,
    'business_id', v_biz.id
  )::text;

  return jsonb_build_object(
    'code', v_new_code,
    'qr_payload', v_qr_payload,
    'promo_id', v_promo.id,
    'business_id', v_biz.id
  );
end;
$$;

revoke all on function reset_store_code(uuid) from public;
grant execute on function reset_store_code(uuid) to authenticated;

-- 5. redeem_at_store(p_code text)
-- Callable by authenticated shoppers. One atomic transaction:
-- Validates static code, checks promo active/dates/limit, gets or creates redemption row,
-- rejects if already redeemed, marks redeemed with redeemed_at, increments promo redeemed_count,
-- and logs 'redeemed' geofence_event with the business id.
-- Return values: 'ok' | 'invalid' | 'already_redeemed' | 'expired' | 'limit_reached'
-- (Static code architecture: no time window, no expired_code)
create or replace function redeem_at_store(p_code text)
returns text
language plpgsql
security definer
set search_path = public
as $$
declare
  v_user_id uuid;
  v_clean_code text;
  v_matched_promo_id uuid;
  v_matched_promo promos%rowtype;
  v_voucher redemptions%rowtype;
begin
  v_user_id := auth.uid();
  if v_user_id is null then
    return 'invalid';
  end if;

  if p_code is null or trim(p_code) = '' then
    return 'invalid';
  end if;

  -- Support both raw 8-character string and JSON QR payload
  if left(trim(p_code), 1) = '{' then
    begin
      v_clean_code := upper(trim((p_code::json->>'code')));
    exception when others then
      v_clean_code := upper(trim(p_code));
    end;
  else
    v_clean_code := upper(trim(p_code));
  end if;

  if length(v_clean_code) < 6 then
    return 'invalid';
  end if;

  -- Find corresponding promo from static promo_store_codes
  select promo_id into v_matched_promo_id
  from promo_store_codes
  where upper(store_code) = v_clean_code;

  if v_matched_promo_id is null then
    return 'invalid';
  end if;

  -- Lock promo row and check promo validity (active, dates, redeem_limit)
  select * into v_matched_promo from promos where id = v_matched_promo_id for update;
  if not found then
    return 'invalid';
  end if;

  if not v_matched_promo.active or now() < v_matched_promo.starts_at or now() > v_matched_promo.ends_at then
    return 'expired';
  end if;

  if v_matched_promo.redeemed_count >= v_matched_promo.redeem_limit then
    return 'limit_reached';
  end if;

  -- Get or create shopper's redemption row
  select * into v_voucher from redemptions
  where user_id = v_user_id and promo_id = v_matched_promo.id
  for update;

  if found then
    if v_voucher.status = 'redeemed' then
      return 'already_redeemed';
    end if;
  else
    insert into redemptions (user_id, promo_id, code, status, created_at)
    values (
      v_user_id,
      v_matched_promo.id,
      'STR-' || upper(substring(md5(random()::text || clock_timestamp()::text) from 1 for 6)),
      'issued',
      now()
    )
    returning * into v_voucher;

    insert into geofence_events (user_id, business_id, promo_id, event_type)
    values (v_user_id, v_matched_promo.business_id, v_matched_promo.id, 'claimed');
  end if;

  -- Burn redemption, increment promo count, and log 'redeemed' event
  update redemptions
  set status = 'redeemed', redeemed_at = now()
  where id = v_voucher.id;

  update promos
  set redeemed_count = redeemed_count + 1
  where id = v_matched_promo.id;

  insert into geofence_events (user_id, business_id, promo_id, event_type)
  values (v_user_id, v_matched_promo.business_id, v_matched_promo.id, 'redeemed');

  return 'ok';
end;
$$;

revoke all on function redeem_at_store(text) from public;
grant execute on function redeem_at_store(text) to authenticated;
