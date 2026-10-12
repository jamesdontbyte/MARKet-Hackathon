-- MARKet Phase 7C: Reverse Redemption Flow Schema Patch
-- NOTE: Do NOT apply automatically. Run manually in Supabase SQL Editor if desired.

-- 1. App Secrets Table (Accessible only by SECURITY DEFINER functions, no client access)
create table if not exists app_secrets (
  key text primary key,
  secret text not null
);

alter table app_secrets enable row level security;
-- No RLS policies are created for app_secrets. Neither anon nor authenticated roles can read or write.

insert into app_secrets (key, secret)
values ('qr_secret', 'market_san_jose_antique_secret_2026')
on conflict (key) do nothing;

-- 2. get_store_code RPC
-- Callable only by the owner of that promo's business.
-- Returns 8-character code and QR payload valid for the current 60s window.
create or replace function get_store_code(p_promo_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_promo promos%rowtype;
  v_biz businesses%rowtype;
  v_secret text;
  v_window bigint;
  v_seconds_remaining int;
  v_expires_at timestamptz;
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

  select secret into v_secret from app_secrets where key = 'qr_secret';
  if v_secret is null then
    v_secret := 'market_san_jose_antique_secret_2026';
  end if;

  v_window := floor(extract(epoch from now()) / 60)::bigint;
  v_seconds_remaining := 60 - (floor(extract(epoch from now()))::bigint % 60);
  v_expires_at := to_timestamp((v_window + 1) * 60);

  -- 8-character code derived server-side from promo_id, business_id, time window, and secret
  v_code := upper(substring(md5(v_promo.id::text || ':' || v_biz.id::text || ':' || v_window::text || ':' || v_secret) from 1 for 8));

  v_qr_payload := json_build_object(
    'app', 'market',
    'code', v_code,
    'promo_id', v_promo.id,
    'business_id', v_biz.id,
    'window', v_window
  )::text;

  return jsonb_build_object(
    'code', v_code,
    'qr_payload', v_qr_payload,
    'promo_id', v_promo.id,
    'business_id', v_biz.id,
    'seconds_remaining', v_seconds_remaining,
    'expires_at', v_expires_at
  );
end;
$$;

revoke all on function get_store_code(uuid) from public;
grant execute on function get_store_code(uuid) to authenticated;

-- 3. redeem_at_store RPC
-- Callable by authenticated shopper. One atomic transaction:
-- Validates code and window (current + previous accepted, older = expired_code).
-- Checks promo activity, dates, limit. Gets or creates shopper's voucher (logs 'claimed' if new).
-- Burns voucher, increments promo count, logs 'redeemed' with business_id.
-- Returns exactly one of: ok | invalid | expired_code | already_redeemed | expired | limit_reached
create or replace function redeem_at_store(p_code text)
returns text
language plpgsql
security definer
set search_path = public
as $$
declare
  v_user_id uuid;
  v_clean_code text;
  v_hint_promo_id uuid;
  v_secret text;
  v_curr_window bigint;
  v_prev_window bigint;
  v_matched_promo promos%rowtype;
  v_found boolean := false;
  v_expired_code boolean := false;
  v_p record;
  v_win bigint;
  v_calc_code text;
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
      if (p_code::json->>'promo_id') is not null then
        v_hint_promo_id := (p_code::json->>'promo_id')::uuid;
      end if;
    exception when others then
      v_clean_code := upper(trim(p_code));
    end;
  else
    v_clean_code := upper(trim(p_code));
  end if;

  if length(v_clean_code) < 6 then
    return 'invalid';
  end if;

  select secret into v_secret from app_secrets where key = 'qr_secret';
  if v_secret is null then
    v_secret := 'market_san_jose_antique_secret_2026';
  end if;

  v_curr_window := floor(extract(epoch from now()) / 60)::bigint;
  v_prev_window := v_curr_window - 1;

  -- Step A: Validate against current and previous 60-second window
  for v_p in (
    select * from promos
    where (v_hint_promo_id is null or id = v_hint_promo_id)
    order by created_at desc
  ) loop
    -- Current window
    v_calc_code := upper(substring(md5(v_p.id::text || ':' || v_p.business_id::text || ':' || v_curr_window::text || ':' || v_secret) from 1 for 8));
    if v_clean_code = v_calc_code then
      v_matched_promo := v_p;
      v_found := true;
      exit;
    end if;

    -- Previous window (accept previous window too)
    v_calc_code := upper(substring(md5(v_p.id::text || ':' || v_p.business_id::text || ':' || v_prev_window::text || ':' || v_secret) from 1 for 8));
    if v_clean_code = v_calc_code then
      v_matched_promo := v_p;
      v_found := true;
      exit;
    end if;
  end loop;

  -- Step B: If not in current/previous window, check older windows (past 30 mins)
  if not v_found then
    for v_p in (
      select * from promos
      where (v_hint_promo_id is null or id = v_hint_promo_id)
    ) loop
      for v_win in (v_curr_window - 2) .. (v_curr_window - 30) loop
        v_calc_code := upper(substring(md5(v_p.id::text || ':' || v_p.business_id::text || ':' || v_win::text || ':' || v_secret) from 1 for 8));
        if v_clean_code = v_calc_code then
          v_expired_code := true;
          exit;
        end if;
      end loop;
      if v_expired_code then exit; end if;
    end loop;

    if v_expired_code then
      return 'expired_code';
    else
      return 'invalid';
    end if;
  end if;

  -- Step C: Lock promo row and check promo dates & limit
  select * into v_matched_promo from promos where id = v_matched_promo.id for update;

  if not v_matched_promo.active or now() < v_matched_promo.starts_at or now() > v_matched_promo.ends_at then
    return 'expired';
  end if;

  if v_matched_promo.redeemed_count >= v_matched_promo.redeem_limit then
    return 'limit_reached';
  end if;

  -- Step D: Get or create shopper's voucher
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

  -- Step E: Burn voucher, update promo count, and log 'redeemed' event
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
