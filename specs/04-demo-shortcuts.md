# 04 — Demo Shortcuts (REQUIRED, keep them)

The venue is not decided and several real services need payment, so these are deliberate.

| Area | Shortcut |
|---|---|
| SMS OTP | Any "Verify via SMS" / send-code button just advances. The code field accepts only `demoOtp` (`123456`) and hints it in small helper text "Demo code: 123456". No SMS is sent. |
| Merchant verification | Waiting screen starts a `demoAutoVerifySeconds` (10 s) timer, then sets `businesses.verified = true` and navigates to the Verified screen. Merchants who log in later with `verified = true` skip it. |
| Geofence venue | Zone = San Jose circle (1500 m). **Hidden "Simulate entering zone" button**: long-press the "MARK" header logo on the Shopper dashboard → bottom sheet with "Simulate entering zone" and "Simulate leaving zone". Same code path as the real trigger. Works anywhere. |
| Analytics fallback | If a query errors or all counts are 0, show these defaults: Pings Sent 1,840 · Delivered & Opened 620 (33.7%) · Store & Promo Views 412 (66.4%) · Claims 142 (34.5%) · Redeemed 118 (83.1%). Real data replaces defaults per metric when > 0. Peak insight text is static. |
| Document uploads | Optional. Failure never blocks registration. |
| Auth | Supabase email+password, no email confirmation, no forgot-password flow (button can show a "Demo: not available" snackbar). |
| Map | OSM tiles; if tiles fail to load, the Roam list view still works. |

Never show "demo" labels on shopper-facing screens except the OTP hint.

## Demo shop: Kape Tahanan
- The demo merchant is **Kape Tahanan** at `10.754707481558897, 121.93442817768808` (~800 m from the
  zone center, inside the 1500 m circle). Seeded as business `00000000-0000-0000-0000-000000000001`.
- Merchant registration step 2 must default to these coordinates (never the phone's current location,
  unless the user taps "Use my current location"), so a live-registered Kape Tahanan lands on the right spot.
- Pre-demo link (run once after the demo merchant account exists, replace the UUID with the merchant's
  `profiles.id` from Supabase Auth → Users):
  ```sql
  update businesses set owner_id = '<MERCHANT_USER_UUID>' where id = '00000000-0000-0000-0000-000000000001';
  ```
  This makes the seeded shop's promos, QR scans and analytics belong to the demo merchant login.
- Promos shown in the shopper notification should lead with Kape Tahanan's promos for the demo.
