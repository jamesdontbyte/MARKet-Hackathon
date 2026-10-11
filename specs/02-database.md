# 02 — Database (Supabase)

Setup steps (user does these once):
1. Create a free Supabase project.
2. Auth → Providers → Email: **disable "Confirm email"**.
3. SQL editor: run `db/schema.sql`, then `db/seed.sql`.
4. Copy Project URL + anon key into `lib/core/env.dart`.

Tables: `profiles`, `businesses`, `products`, `promos`, `stash`, `redemptions`, `geofence_events`
(+ private Storage bucket `merchant-docs`). Full DDL + RLS in `db/schema.sql`.

## Data rules
- `businesses.radius_m` defaults 1500 for the demo. Geofence uses config constants unless
  `perBusinessGeofence = true`.
- A promo is **active** when `active` and `now()` between `starts_at` and `ends_at` and
  `redeemed_count < redeem_limit`.
- Shoppers see only `businesses.verified = true`.
- `redemptions.code`: 8-char uppercase alphanumeric, unique. One redemption per (user, promo).
- `geofence_events.event_type`: `ping_sent` (notification shown), `opened` (notification tapped),
  `viewed` (promo/store viewed), `claimed` (saved to Stash or voucher created), `redeemed` (QR scanned).
- Merchant analytics = counts of these events for that merchant's business/promos in last 7 days.
- Client code talks to Supabase through `lib/services/data_service.dart` only.
