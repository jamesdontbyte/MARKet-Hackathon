# 00 — Overview

**App name:** MARKet — MSME hyperlocal discovery, San Jose de Buenavista, Antique.
**Stack:** Flutter (Android), Supabase free tier (Postgres, Auth email+password, Storage).
**Map:** `flutter_map` + OpenStreetMap tiles (free, no key).

## Roles
- **Shopper:** registers, picks interests, sees nearby verified businesses and promos, saves promos
  to Stash, receives geofence notifications, shows a QR voucher at the counter.
- **Merchant (MSME):** registers a business (4 steps), waits for verification, manages catalog and
  promos, scans shopper QR vouchers, views analytics.

## Demo-critical loop (must work flawlessly)
Shopper logs in → starts promo alerts → enters San Jose zone → local notification appears
(even screen-locked) → tap opens promo → Save to Stash → Open Voucher (QR) →
Merchant scans QR → redemption recorded → Merchant analytics update.

## Config constants (`lib/core/config.dart`)
```dart
const demoZoneName = 'San Jose de Buenavista';
const demoZoneLat = 10.7674886;
const demoZoneLng = 121.9428977;
const demoZoneRadiusMeters = 4400.0;   // circle covering all of San Jose (venue undecided)
const geofenceExitBufferMeters = 30.0; // anti-jitter
const notificationCooldown = Duration(minutes: 3); // demo; production: hours
const demoOtp = '123456';
const demoAutoVerifySeconds = 10;
// Demo shop = Kape Tahanan (real coordinates)
const demoShopName = 'Kape Tahanan';
const demoShopLat = 10.754707481558897;
const demoShopLng = 121.93442817768808;
const perBusinessGeofence = false;     // true later: use businesses.radius_m (e.g. 100)
```

## Env (`lib/core/env.dart`, user fills in)
```dart
const supabaseUrl = 'PASTE_PROJECT_URL';
const supabaseAnonKey = 'PASTE_ANON_KEY';
```

## Out of scope
iOS, FCM/push, real SMS, payments, chat, reviews posting, admin dashboard (admin = auto-verify timer).
