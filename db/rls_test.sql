-- ============================================================================
-- MARKet Phase 2 Checkpoint: Two-Account RLS Test Script
-- Run this in the Supabase SQL Editor.
-- Tests:
-- 1. Shopper A cannot read Shopper B's vouchers.
-- 2. Merchant B cannot redeem Merchant A's voucher code.
-- 3. Shopper cannot directly update a redemption row.
-- ============================================================================

do $$
declare
  u_shopper_a uuid := gen_random_uuid();
  u_shopper_b uuid := gen_random_uuid();
  u_merchant_a uuid := gen_random_uuid();
  u_merchant_b uuid := gen_random_uuid();

  biz_a_id uuid := gen_random_uuid();
  biz_b_id uuid := gen_random_uuid();

  promo_a_id uuid := gen_random_uuid();
  promo_b_id uuid := gen_random_uuid();

  vouch_b_id uuid := gen_random_uuid();
  vouch_a_code text := 'TESTAAA1';
  vouch_b_code text := 'TESTBBB1';

  test1_count int;
  test2_result text;
  test3_updated int;
begin
  raise notice '=== Setting Up RLS Test Fixtures ===';

  -- Create profiles
  insert into profiles (id, role, full_name) values
    (u_shopper_a, 'shopper', 'Shopper Alice'),
    (u_shopper_b, 'shopper', 'Shopper Bob'),
    (u_merchant_a, 'merchant', 'Merchant Alice (Kape Tahanan)'),
    (u_merchant_b, 'merchant', 'Merchant Bob (Antique Crafts)');

  -- Create businesses
  insert into businesses (id, owner_id, name, category, lat, lng, verified) values
    (biz_a_id, u_merchant_a, 'Kape Tahanan', 'cafe', 10.7547, 121.9344, true),
    (biz_b_id, u_merchant_b, 'Antique Crafts', 'retail', 10.7500, 121.9300, true);

  -- Create promos
  insert into promos (id, business_id, title, promo_type, value_label, redeem_limit, redeemed_count, active) values
    (promo_a_id, biz_a_id, 'Merchant A BOGO', 'bogo', 'BOGO', 100, 0, true),
    (promo_b_id, biz_b_id, 'Merchant B 20% Off', 'percent', '20% OFF', 100, 0, true);

  -- Issue voucher for Shopper A on Promo A
  insert into redemptions (id, promo_id, user_id, code, status) values
    (gen_random_uuid(), promo_a_id, u_shopper_a, vouch_a_code, 'issued');

  -- Issue voucher for Shopper B on Promo B
  insert into redemptions (id, promo_id, user_id, code, status) values
    (vouch_b_id, promo_b_id, u_shopper_b, vouch_b_code, 'issued');

  -- --------------------------------------------------------------------------
  -- TEST 1: Shopper A cannot read Shopper B's vouchers
  -- --------------------------------------------------------------------------
  execute 'set local role authenticated';
  perform set_config('request.jwt.claims', json_build_object('sub', u_shopper_a::text)::text, true);

  select count(*) into test1_count from redemptions where user_id = u_shopper_b;
  if test1_count = 0 then
    raise notice '[PASS] Test 1: Shopper A sees 0 rows when querying Shopper B vouchers.';
  else
    raise exception '[FAIL] Test 1: Shopper A read % rows belonging to Shopper B!', test1_count;
  end if;

  -- --------------------------------------------------------------------------
  -- TEST 2: Merchant B cannot redeem Merchant A's code
  -- --------------------------------------------------------------------------
  execute 'set local role authenticated';
  perform set_config('request.jwt.claims', json_build_object('sub', u_merchant_b::text)::text, true);

  test2_result := redeem_voucher(vouch_a_code);
  if test2_result = 'not_your_promo' then
    raise notice '[PASS] Test 2: Merchant B redeem_voucher returned "not_your_promo".';
  else
    raise exception '[FAIL] Test 2: Expected "not_your_promo", got "%"!', test2_result;
  end if;

  -- --------------------------------------------------------------------------
  -- TEST 3: Shopper cannot update a redemption row
  -- --------------------------------------------------------------------------
  execute 'set local role authenticated';
  perform set_config('request.jwt.claims', json_build_object('sub', u_shopper_a::text)::text, true);

  -- Shopper attempts to update own voucher status directly
  update redemptions set status = 'redeemed' where user_id = u_shopper_a;
  get diagnostics test3_updated = row_count;

  if test3_updated = 0 then
    raise notice '[PASS] Test 3: Shopper direct update affected 0 rows (blocked by RLS).';
  else
    raise exception '[FAIL] Test 3: Shopper direct update bypassed RLS and modified % rows!', test3_updated;
  end if;

  -- Cleanup test data
  execute 'set local role postgres';
  delete from profiles where id in (u_shopper_a, u_shopper_b, u_merchant_a, u_merchant_b);

  raise notice '=== ALL RLS SECURITY CHECKS PASSED ===';
end;
$$;
