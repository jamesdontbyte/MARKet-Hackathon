# 03 — Geofence & Notifications (the core feature)

**Start from `reference/geofence/*.dart`.** It already implements: permission flow, foreground-service
position stream, enter/exit detection with exit buffer, per-zone cooldown, local notifications.
Copy into `lib/services/` and adapt. Do not rewrite from scratch, do not swap in a paid SDK.

## Behavior
1. Starts after login (shopper only). Stops on logout.
2. Zone = San Jose circle from `config.dart` (center 10.7525111, 121.9413404, 1500 m).
   Distance via `Geolocator.distanceBetween`. Exit buffer 30 m. Cooldown from config.
3. On ENTER (outside→inside, or first fix while inside):
   - Query active promos from verified businesses matching `profiles.interests`
     (no interests → all). Pick up to 3.
   - Show ONE notification: title "Promos near you in San Jose", body = top promo title +
     "(+N more)". Payload = `promoId` of the top promo.
   - Insert `geofence_events` row: `ping_sent` (business_id of the top promo's business, promo_id).
   - Respect `profiles.prefs.flash_promos`; if false, log only, do not notify.
4. Notification tap → `navigatorKey` → Promo detail (if app killed/cold start, handle
   `getNotificationAppLaunchDetails`). Insert `opened` event.
5. `perBusinessGeofence = true` (off by default): one zone per business using `radius_m`,
   notification per business. Implement the switch but leave it off.
6. Expiry reminders (optional, low priority): schedule a local notification 24h before a stashed
   promo's `ends_at` if `prefs.expiry_reminders`.

## Permissions UX
Permission explainer screen (no frame) → request notifications → while-in-use location →
`Permission.locationAlways`. If denied: show non-blocking banner on dashboard with
"Enable" → `openAppSettings()`. Account screen shows live state.

## Android manifest permissions
INTERNET, ACCESS_FINE_LOCATION, ACCESS_COARSE_LOCATION, ACCESS_BACKGROUND_LOCATION,
FOREGROUND_SERVICE, FOREGROUND_SERVICE_LOCATION, POST_NOTIFICATIONS, CAMERA (QR scanner).
Plus desugaring/minSdk per `reference/geofence/build_gradle_notes.txt`.

## Simulate button (see 04)
`GeofenceService.simulateEnter()` runs steps 3–4 immediately, ignoring cooldown, no GPS needed.

## Verification gate (device only)
Agent cannot verify this in a terminal. After building, output a manual test script:
1. Install APK on a real Android phone, log in as shopper, grant all permissions.
2. Tap Start / confirm persistent "Promo alerts are on" notification.
3. Press "Simulate entering zone" → notification appears → tap → Promo detail opens.
4. Lock screen, use a mock-location app to move outside then inside the zone → notification appears.
5. Re-enter within cooldown → no second notification.
