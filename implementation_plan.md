# Implementation Plan — MARKet (Hyperlocal MSME Promo Discovery)

**Target Platform:** Android (Flutter)  
**Backend:** Supabase (Auth, Postgres with RLS & `redeem_voucher` RPC, Storage)  
**Location & Geofencing:** `geolocator` foreground service + local distance calculation  
**Design Standard:** Stitch Export (`design/DESIGN.md`, `design/stitch_msme_promo_mobile_dashboard/`)

---

## Architectural & Spec Decisions

1. **Database & Schema Patch (`db/schema_patch.sql`):**
   - Already applied in Supabase.
   - Merchant voucher redemption executes exclusively via `supabase.rpc('redeem_voucher', params: {'p_code': code})` which atomically checks promo validity, limits, and updates redemption/promo state and logs the `redeemed` event.
   - Shoppers only query businesses where `verified = true` (or owner's own business).
   - Storage bucket `merchant-docs` permits document update/upsert for authenticated owners.
2. **One-Tap Demo Logins:**
   - When `demoMode = true` in `lib/core/config.dart`, the Login screen provides one-tap shortcut buttons: `"Demo Shopper"` and `"Demo Merchant (Kape Tahanan)"` using pre-seeded auth credentials.
3. **Shopper OTP Verification:**
   - Registration form advances on "Create Account & Continue" to display a bottom sheet modal for the 6-digit OTP with helper text `"Demo code: 123456"`. Submitting `123456` verifies the user and proceeds to Interest Selection.
4. **Voucher & Event Lifecycle:**
   - "Save to Stash" writes exclusively to the `stash` table.
   - Opening the Voucher screen for the first time issues the unique 8-character `redemptions` row (status `issued`) and logs a `claimed` event in `geofence_events`. Subsequent opens reuse the existing voucher.
   - Geofence notification tap logs an `opened` event in `geofence_events`.
5. **Zero-Interest Match Geofence Fallback:**
   - When entering the San Jose zone, if no active promos match the shopper's selected interests: if `demoMode = true`, falls back to the top overall active promo (e.g. Kape Tahanan BOGO); if `demoMode = false`, remains silent. Controlled by `fallbackToTopPromoIfNoMatch` in `config.dart`.
6. **Map Tile Failures & List View Fallback:**
   - On the Roam map screen, if OSM tiles fail to load repeatedly, the view displays a transient notice ("Map tiles unavailable — showing list view") and switches to the List view. The "Map | List" toggle remains interactive.
7. **Storefront Cover Image Fallback:**
   - `businesses.cover_url` is nullable. If null or unable to load, the UI displays bundled category placeholder assets (`assets/categories/{category}.png`).
8. **Canonical Category Slugs:**
   - Account interest chips, onboarding interest selection, and category filters use the 8 canonical slugs: `food`, `cafe`, `salon`, `retail`, `grocery`, `wellness`, `services`, `travel`.
9. **Merchant Multi-Step Registration Resume:**
   - Form state across steps 1–4 is retained in `MerchantRegController` (`ChangeNotifier`). If an authenticated merchant has a profile but no `businesses` row, the app routes directly to resume at Step 2 (Business Information).
10. **Environment Isolation:**
    - `lib/core/env.dart` is added to `.gitignore`. A template `lib/core/env.example.dart` is tracked in version control.

---

## Directory Structure
```
lib/
  main.dart
  core/
    theme.dart                    # Design tokens: Plus Jakarta Sans, colors, spacing, radii, elevation
    env.dart                      # Supabase URL & anon key (gitignored)
    env.example.dart              # Template for environment configuration
    config.dart                   # Demo zone, shop coordinates, OTP, flags (demoMode, fallbackToTopPromoIfNoMatch)
    supabase.dart                 # Supabase client initialization wrapper
  models/
    profile.dart                  # User profile model & JSON serialization
    business.dart                 # MSME business model (including nullable cover_url & category fallback)
    product.dart                  # Catalog item model
    promo.dart                    # Promotion model
    redemption.dart               # Voucher redemption model
  services/
    auth_service.dart             # Auth operations, session stream, one-tap demo logins, role routing
    data_service.dart             # Queries/mutations, rpc('redeem_voucher'), geofence_events logging
    notification_service.dart     # flutter_local_notifications wrapper
    geofence_service.dart         # Position stream, distance math, cooldown, demo enter/exit simulation
    merchant_reg_controller.dart  # ChangeNotifier persisting multi-step merchant registration form data
  screens/
    shared/
      splash_screen.dart          # 2s splash, session check -> role/reg routing
      role_selection_screen.dart  # Merchant vs Shopper role selection
      login_screen.dart           # Email/password authentication + demo one-tap shortcuts (when demoMode is true)
      permission_explainer_screen.dart # 3-step location & notification explainer
    shopper/
      register_screen.dart        # Shopper signup + OTP bottom sheet modal ("Demo code: 123456")
      interests_screen.dart       # Category selection grid (8 canonical slugs)
      dashboard_screen.dart       # Recommendation cards, promos, long-press MARK demo trigger
      roam_screen.dart            # flutter_map + OSM, zone circle, business markers, tile retry & auto-list fallback
      stash_screen.dart           # Saved promos, status tabs, "Open Voucher" launcher
      account_screen.dart         # Preferences, canonical interest chips, live permissions, notification toggles, logout
      storefront_screen.dart      # Business profile, cover_url / category asset fallback, catalog, active promos
      promo_detail_screen.dart    # Promo details, save to stash, get voucher, viewed/opened event logging
      voucher_screen.dart         # QR voucher generator (qr_flutter, creates redemptions row & logs claimed on first open)
    merchant/
      reg_step1_screen.dart       # Owner basics + demo OTP
      reg_step2_screen.dart       # Business info, coordinates (default Kape Tahanan), resume entrypoint
      reg_step3_screen.dart       # Permit uploads (Supabase Storage 'merchant-docs')
      reg_step4_review_screen.dart# Review summary & submit unverified business
      waiting_screen.dart         # 10s auto-verification timer
      verified_screen.dart        # Verification success confirmation
      dashboard_screen.dart       # Immersive scroll header, quick stats, active promos
      catalog_screen.dart         # Products & services CRUD + add item modal
      promotions_screen.dart      # Promos management + promo creation form
      scan_screen.dart            # mobile_scanner QR reader calling rpc('redeem_voucher') + manual fallback
      analytics_screen.dart       # 7-day conversion funnel & footfall insights (with demo fallbacks)
      account_screen.dart         # Business profile, permit checklist, logout
  widgets/
    app_buttons.dart              # PrimaryButton, SecondaryButton, DestructiveButton (min 48dp target)
    app_card.dart                 # Elevation Level 1 & 2 containers
    app_text_field.dart           # Themed inputs with 48dp touch targets, focus borders
    filter_chip.dart              # Themed category & status filter chips
    status_pill.dart              # Verified MSME badge, Open/Closed badge
    promo_badge.dart              # Dashed border discount tags (#BAE6FD border, #F0F9FF fill)
    storefront_card.dart          # 16:9 exterior preview with bottom gradient overlay & placeholder fallback
    shopper_bottom_nav.dart       # 4-tab shopper navigation bar
    merchant_bottom_nav.dart      # 4-tab merchant navigation bar
```

---

## Phase Breakdown & Acceptance Gates

### Phase 0: Project Bootstrap & Android Foundation
**Goal:** Initialize Flutter project, setup `.gitignore`, configure dependencies, Android manifest, build settings, assets, and core configuration.
- **Files to create/modify:**
  - `.gitignore` — Ignore `lib/core/env.dart` and build artifacts.
  - `pubspec.yaml` — Pre-approved dependencies (`supabase_flutter`, `geolocator`, `permission_handler`, `flutter_local_notifications`, `flutter_map`, `latlong2`, `qr_flutter`, `mobile_scanner`, `file_picker`, `google_fonts`). Asset declarations.
  - `android/app/build.gradle` — Core library desugaring (`desugar_jdk_libs:2.1.4`), `minSdkVersion 21`, Java 1.8 compatibility.
  - `android/app/src/main/AndroidManifest.xml` — Permissions: `INTERNET`, `ACCESS_FINE_LOCATION`, `ACCESS_COARSE_LOCATION`, `ACCESS_BACKGROUND_LOCATION`, `FOREGROUND_SERVICE`, `FOREGROUND_SERVICE_LOCATION`, `POST_NOTIFICATIONS`, `CAMERA`.
  - `assets/` — Logos copied from `design/stitch_msme_promo_mobile_dashboard/` into `assets/logos/`, bundled category fallback images in `assets/categories/`.
  - `lib/core/env.example.dart` & `lib/core/env.dart`.
  - `lib/core/config.dart` — Zone coordinates, `demoOtp = '123456'`, `demoMode = true`, `fallbackToTopPromoIfNoMatch = true`, cooldown durations.
  - `lib/core/theme.dart` — Plus Jakarta Sans typography, ColorScheme, MarketColors, BoxShadow tokens, shape radii.
  - `lib/core/supabase.dart` — Supabase client initialization wrapper.
- **Acceptance Checks:**
  - `flutter pub get` completes cleanly.
  - `flutter analyze` passes.
  - `flutter build apk --debug` succeeds.

---

### Phase 0.5: Geofence Spike (Device Hardware Verification)
**Goal:** Verify background location foreground service, "Allow all the time" permission, lockscreen notification delivery, and notification tap handling on a real Android device using the reference implementation.
- **Files to run/test:**
  - Standalone spike harness based on `reference/geofence/`.
- **Hardware Verification Checklist (On-Device Test):**
  1. Build and install spike APK on physical Android phone.
  2. Launch app; grant While-In-Use Location and Notifications (Android 13+).
  3. Grant Background Location ("Allow all the time" in Settings).
  4. Confirm persistent foreground service notification is active: `"Promo alerts are on — Looking for deals near you"`.
  5. Lock device screen.
  6. Trigger simulated zone entry or use mock-location to move inside San Jose zone.
  7. Confirm notification appears on lockscreen: `"Welcome to San Jose!"`.
  8. Tap notification -> confirm device opens the app screen.
- **CHECKPOINT:** Stop after Phase 0.5 and wait for user's on-device test confirmation before proceeding.

---

### Phase 1: Design System & Reusable UI Components
**Goal:** Build reusable UI components matching Stitch frames and `design/DESIGN.md`.
- **Files to create:**
  - `lib/widgets/app_buttons.dart` — PrimaryButton (cyan `#3EC4FF` fill, dark text `#0B1C30`, min 48dp), SecondaryButton, DestructiveButton. Pressed & disabled states.
  - `lib/widgets/app_card.dart` — Elevation Level 1 border `#F1F5F9`, soft diffused shadow; Level 2 elevated sheet container.
  - `lib/widgets/app_text_field.dart` — 48dp height target, 10px radius, `#3EC4FF` focus ring.
  - `lib/widgets/filter_chip.dart` — Pill shape, inactive/active styling.
  - `lib/widgets/status_pill.dart` — Verified MSME badge, Open/Closed badge.
  - `lib/widgets/promo_badge.dart` — `#BAE6FD` dashed boundary, `#F0F9FF` background, `#0369A1` text.
  - `lib/widgets/storefront_card.dart` — 16:9 exterior preview with bottom gradient overlay & category placeholder fallback.
  - `lib/widgets/shopper_bottom_nav.dart` — 4-tab shopper navigation bar.
  - `lib/widgets/merchant_bottom_nav.dart` — 4-tab merchant navigation bar.
- **Acceptance Checks:**
  - `flutter analyze` passes with 0 warnings.
  - All interactive elements meet minimum 48x48dp target.

---

### Phase 2: Data Models, Supabase DataService & Geofence Engine
**Goal:** Implement data models, atomic RPC calls, and foreground geofence engine with promo matching and simulation triggers.
- **Files to create:**
  - `lib/models/profile.dart` — Profiles table mapping (role, canonical interests, prefs).
  - `lib/models/business.dart` — MSME business model (`cover_url`, lat/lng, category, verified, radius).
  - `lib/models/product.dart` — Catalog product item.
  - `lib/models/promo.dart` — Promotion item with active status helper (`active` and date range and `redeemed_count < redeem_limit`).
  - `lib/models/redemption.dart` — 8-char uppercase alphanumeric code, status (`issued`/`redeemed`).
  - `lib/services/merchant_reg_controller.dart` — `ChangeNotifier` holding multi-step form data across steps 1–4.
  - `lib/services/auth_service.dart` — Email/pass sign-up & login, one-tap demo logins, session stream.
  - `lib/services/data_service.dart` — Fetch verified businesses, promos by interest, save/remove stash, issue redemption, `rpc('redeem_voucher')`, `geofence_events` logging, analytics funnel counts with fallback numbers.
  - `lib/services/notification_service.dart` — Local notifications initialization, promo channel configuration, tap payload handling.
  - `lib/services/geofence_service.dart` — Foreground service location stream, distance calculation, cooldown, zero-match fallback logic, `simulateEnter()`, `simulateExit()`.
- **Acceptance Checks:**
  - `flutter analyze` passes.
  - Unit tests verify models correctly serialize/deserialize database payloads.
  - Unit tests verify `DataService.redeemVoucher` invokes `rpc('redeem_voucher')` and handles all status codes (`ok`, `invalid`, `not_your_promo`, `already_redeemed`, `expired`, `limit_reached`).
- **CHECKPOINT:** Phase 2 Passed.

---

### Phase 3: Shared Authentication, Role Selection, Login & Shopper Onboarding
**Goal:** Implement Splash, Role Selection, Login (with demo shortcuts), Shopper Registration (with demo OTP modal), and Interest Selection.
- **Files to create/modify:**
  - `lib/screens/shared/splash_screen.dart` — 2s splash, checks Supabase session -> routes to Shopper destination (or Interests if empty), Merchant destination (Dashboard if verified, Waiting if unverified, Reg if no business), or Role Selection.
  - `lib/screens/shared/role_selection_screen.dart` — Matches `market_role_selection` frame. Selectable cards for Merchant & Shopper.
  - `lib/screens/shared/login_screen.dart` — Email/password login with loading/error states + one-tap "Demo Shopper" and "Demo Merchant (Kape Tahanan)" quick login buttons (shown when `demoMode == true`).
  - `lib/screens/shopper/register_screen.dart` — Matches `market_consumer_registration`. Step 1 basic profile with validation. "Create Account & Continue" opens OTP modal bottom sheet ("Demo code: 123456") which creates auth user + `profiles` row (`role: shopper`) via `AuthService.signUpShopper`.
  - `lib/screens/shopper/interests_screen.dart` — Matches `market_consumer_interest_selection_mobile`. 8 canonical category cards with multi-select counter, saves to `profiles.interests` via `AuthService.updateInterests`, "Skip for now" option.
  - `lib/main.dart` — Configured named routes and startup routing starting at `SplashScreen`. Retains `/spike` route for geofence verification.
- **Acceptance Checks:**
  - Splash routes correctly based on user role and business registration state.
  - Demo login buttons instantly log into pre-seeded accounts.
  - Registration opens OTP bottom sheet with "Demo code: 123456", creates account upon entering demo code.
  - Interest selection saves chosen slugs to profile.
  - `flutter analyze` passes with 0 warnings.
  - `flutter test` passes.
  - `flutter build apk --debug` succeeds.
- **CHECKPOINT:** Phase 3 Passed.

---

### Phase 4: Shopper Experience, Hyperlocal Discovery & Notification Flow
**Goal:** Implement full shopper portal: permission explainer, 4-tab dashboard landing with missing permissions banner & MARK long-press simulator, real OSM map discovery with fallback, storefront catalog, promo detail with viewed/opened logging, stash with status tabs, QR voucher issuance, and account preferences.
- **Files to create/modify:**
  - `lib/screens/shared/permission_explainer_screen.dart` — 3 steps: foreground location, "Allow all the time" separate step, then notifications.
  - `lib/screens/shopper/dashboard_screen.dart` — Shopper landing screen (replaces placeholder). "Businesses for You" filtered by `profiles.interests`, popular businesses, featured promos. Missing permissions banner. Long-press "MARK" header logo opens simulation sheet ("Simulate entering zone", "Simulate leaving zone", "Open Geofence Spike Screen").
  - `lib/screens/shopper/roam_screen.dart` — `flutter_map` + OSM tiles, 1500m zone circle, verified business markers, user location pulse, bottom quick-view sheet, Map/List toggle, and auto-switch to List view if tiles fail.
  - `lib/screens/shopper/storefront_screen.dart` — Business header (`cover_url` / category fallback, verified badge), active promos with Save button, catalog products menu.
  - `lib/screens/shopper/promo_detail_screen.dart` — Promo details, "Save to Stash", "Get Voucher". Logs `viewed` on in-app open; logs `opened` only when opened from notification tap.
  - `lib/screens/shopper/stash_screen.dart` — Saved promos with 4 status tabs (All/Active/Expiring/Expired), "Open Voucher" action, empty states.
  - `lib/screens/shopper/voucher_screen.dart` — Generates 8-char code & QR via `qr_flutter`. Issues `redemptions` row and logs `claimed` only on first open.
  - `lib/screens/shopper/account_screen.dart` — Profile details, canonical interest chips from 8 slugs with edit action, live permissions check + `openAppSettings()`, notification toggles in `profiles.prefs`, link to geofence spike, logout.
  - `lib/services/notification_service.dart` & `lib/main.dart` — Notification title "Promos near you in San Jose" everywhere; cold-start notification tap routing directly to `promo_detail_screen`.
  - `lib/services/data_service.dart` — Add `fetchPromoById` and helper queries.
- **Acceptance Checks:**
  - Notification title is "Promos near you in San Jose" everywhere.
  - Tapping promo notification opens `promo_detail_screen` (cold start and running).
  - Telemetry: `viewed` on in-app browse, `opened` on notification tap, `claimed` on voucher creation.
  - "Businesses for You" filtered by user interests; only verified businesses shown.
  - Loading, empty, and error states present on every screen.
  - `flutter analyze` passes (0 issues).
  - `flutter test` passes.
  - `flutter build apk --debug` succeeds.
- **CHECKPOINT:** Phase 4 Passed. All shopper experience screens, OSM discovery, telemetry logging, permissions banner, and geofence simulation sheets built and verified. Ready for user on-device review.

---

### Phase 5a: MSME Merchant Portal & Registration Wizard (COMPLETED)
**Goal:** Implement 4-step merchant registration with resume capability, 10s auto-verification, Dashboard, Catalog & Promos CRUD, Account & Compliance screen. (Scan & Analytics deferred to Phase 5b).
- **Files created/modified:**
  - `lib/services/data_service.dart` — Added `updateProduct`, `updatePromo`, `deletePromo`.
  - `lib/widgets/merchant_bottom_nav.dart` — 4-tab bar (Dashboard 0, Catalog 1, Analytics 2, Account 3).
  - `lib/screens/merchant/merchant_reg_controller.dart` — Multi-step form controller with resume repopulation, GPS fallback, and file upload to `merchant-docs/<uid>/`.
  - `lib/screens/merchant/widgets/merchant_reg_stepper.dart` — 4-step wizard stepper.
  - `lib/screens/merchant/reg_step1_screen.dart` — Owner credentials & demo OTP ("123456").
  - `lib/screens/merchant/reg_step2_screen.dart` — Business info, 8 canonical category chips, GPS fix fallback.
  - `lib/screens/merchant/reg_step3_screen.dart` — 4 document dropzones with non-blocking fallback.
  - `lib/screens/merchant/reg_step4_review_screen.dart` — Summary review & unverified business submission.
  - `lib/screens/merchant/waiting_screen.dart` — 10s auto-verify timer updating `businesses.verified = true`.
  - `lib/screens/merchant/verified_screen.dart` — Feature unlocked celebration.
  - `lib/screens/merchant/dashboard_screen.dart` — Immersive hero header, performance stats, active promos, about section.
  - `lib/screens/merchant/catalog_screen.dart` — Products CRUD with Add/Edit Item modal and delete confirmation.
  - `lib/screens/merchant/promotions_screen.dart` — Promos list + Create Promo modal + "Scan QR" button with "Coming in Phase 5b" dialog.
  - `lib/screens/merchant/account_screen.dart` — Business profile, Compliance Vault, geofence status, logout.
  - `lib/screens/merchant/merchant_reg_entry_screen.dart` — Entrypoint resuming at Step 2 if profile exists without business.
  - `lib/main.dart` — Wired all merchant named routes.
  - `test/merchant_screens_test.dart` — 13 tests covering controller, stepper, all 4 reg screens, waiting, verified, dashboard, catalog, promos, and account.
- **Acceptance Checks:**
  - Resuming registration re-populates state in Step 2 via `MerchantRegController`.
  - 10-second auto-verify timer in `WaitingScreen` marks business verified.
  - Verified business immediately appears in shopper dashboard and roam discovery.
  - Catalog supports adding, editing, and deleting products.
  - Promotions supports creating promotions with discounts and validity dates.
  - `flutter analyze` passes (0 issues).
  - `flutter test` passes (31/31 tests pass).
  - `flutter build apk --debug` succeeds.
- **CHECKPOINT:** Phase 5a Completed.

---

### Phase 5b: QR Scanner & MSME Analytics
**Goal:** Implement QR camera scanner calling `redeem_voucher` RPC and 7-day conversion funnel analytics.
- **Files created/modified:**
  - `lib/models/merchant_analytics.dart` — `FunnelStep` and `MerchantAnalyticsData` with fallback benchmarks from `specs/04-demo-shortcuts.md`.
  - `lib/services/data_service.dart` — Added `fetchMerchantFunnel(businessId)` querying `geofence_events`.
  - `lib/widgets/app_text_field.dart` — Added `textCapitalization` and `inputFormatters` support with `services.dart` import.
  - `lib/screens/merchant/scan_screen.dart` — `mobile_scanner` QR reader with torch/flip toggles, 8-character manual code fallback, camera permission fallback, 1.5s debounce, and distinct result cards for `ok`, `already_redeemed`, `not_your_promo`, `expired`, `limit_reached`, `invalid`.
  - `lib/screens/merchant/analytics_screen.dart` — 7-day conversion funnel matching Stitch layout (`market_tab_3_analytics`) with animated radar range visualizer, real vs "Sample data" badges, and peak footfall insights card.
  - `lib/screens/merchant/promotions_screen.dart` — Replaced placeholder with navigation to `MerchantScanScreen`.
  - `lib/screens/merchant/dashboard_screen.dart` — Replaced placeholder bottom nav with `MerchantAnalyticsScreen` and wired real vs sample data stats.
  - `lib/screens/merchant/catalog_screen.dart` & `account_screen.dart` — Replaced placeholder bottom nav with `MerchantAnalyticsScreen`.
  - `test/scan_screen_test.dart` — Hand-written `FakeSupabaseClient` test suite verifying RPC parameter validation, result state UI cards, and analytics screen components.
- **Acceptance Checks:**
  - QR Scanner validates code via `redeem_voucher` RPC and shows correct result (`ok`, `already_redeemed`, `expired`, `not_your_promo`, `limit_reached`, `invalid`).
  - Debounced scanning prevents double RPC calls.
  - Camera permission denied presents manual entry fallback.
  - Analytics reflect real vs sample fallback numbers.
  - `flutter analyze` passes (0 issues).
  - `flutter test` passes (38/38 tests pass).
  - `flutter build apk --debug` succeeds.
- **CHECKPOINT:** Phase 5b Completed.

---

### Phase 6: End-to-End Integration & Final Hardening Gate
**Goal:** Verify entire demo loop, terminal analysis, harden visual tokens & lifecycle, and compile final release APK.
- **Terminal Verification:**
  - `flutter analyze`: Passed (0 errors, 0 warnings).
  - `flutter test`: Passed (38/38 tests passed).
  - `flutter build apk --release`: Passed (`build/app/outputs/flutter-apk/app-release.apk`, 71.9MB).
- **Hardening Completed:**
  - `GeofenceService.instance.stop()` invoked on user logout in `AuthService.signOut()`, disposing stream subscriptions, safety poll timers, and fallback timers.
  - Manifest permissions and foreground service (`foregroundServiceType="location"`) verified and explicitly declared.
  - Spike access guarded strictly behind `demoMode = true` in routes, Shopper Dashboard simulation sheet, Shopper Account screen, and Merchant Account screen.
  - Zero debug prints in application codebase.
  - All fallback numbers tagged with "Sample data" labels per spec.
  - `env.dart` is gitignored; `env.example.dart` is tracked; zero service-role keys anywhere in repository.
  - One-page demo presentation script and contingency playbook saved to `docs/demo_script.md`.
- **CHECKPOINT:** Phase 6 Completed. App ready for Hackathon presentation.

---

### Phase 7A: Production Polish & Demo Decoupling
**Goal:** Decouple codebase from demo shortcuts, remove sample data and fallback numbers, enforce real business ownership and live coordinates, retain OTP sheets and 10s auto-verify unconditionally, gate zone simulation behind `emergencySimulate`, delete `lib/spike/`.

- **Key Tasks:**
  1. Remove `demoMode` flag. Add `emergencySimulate = true` in `lib/core/config.dart`. Keep shopper and merchant OTP sheets (with "Demo code: 123456") and 10-second merchant auto-verification active without depending on any flag.
  2. Remove "Demo Shopper" and "Demo Merchant (Kape Tahanan)" quick-login buttons from `LoginScreen`, along with demo sign-in methods in `AuthService` and demo credentials from `env.dart`/`env.example.dart`.
  3. Keep long-press on "MARK" logo in Shopper Dashboard header, gated by `emergencySimulate`. Simulation sheet contains only "Simulate entering zone" and "Simulate leaving zone". If no active promo exists, display "No active promos to simulate".
  4. Delete `lib/spike/`, `/spike` route in `main.dart`, and every link to it.
  5. Merchant waiting screen: Keep 10-second timer. Remove manual bypass button and demo wording ("Demo: ...", "Demo Bypass").
  6. Merchant side: Always use logged-in owner's business looked up by `owner_id`. Remove Kape Tahanan defaults, `demoShopLat`/`demoShopLng`, and prefilled category. Registration Step 2 starts empty. "Use my current location" requests permission; if denied/unavailable, displays error without silently falling back to fixed coordinates.
  7. Remove all sample data, fallback funnel numbers, and "Sample data" badges. Show real counts. Zero displays 0 with empty state.
  8. Remove `fallbackToTopPromoIfNoMatch` and any placeholder content shown as real data. Empty state for lists without data.
  9. Shopper dashboard distances: Use real user location. If unavailable, display no distance badge. Remove demo-zone fallback coordinates.
  10. Search `lib/` for "demo", "sample", "hackathon", "mock", "Kape", "Tahanan", report each hit and disposition.
  11. Update tests that depended on removed demo behavior. Verify via `flutter analyze`, `flutter test`, and `flutter build apk --debug`.
- **Status:** COMPLETED.
  - `flutter analyze`: 0 issues found.
  - `flutter test`: 39/39 tests passed.
  - `flutter build apk --debug`: Built successfully (`build\app\outputs\flutter-apk\app-debug.apk`).
- **CHECKPOINT:** Phase 7A Completed.

---

### Phase 7B: Real MSME Geofencing & Local Notifications Engine
**Goal:** Promo alerts originate dynamically from real verified businesses with active promos instead of hardcoded zones.
- **Key Tasks:**
  1. `lib/core/config.dart`: Remove `demoZoneName`, `demoZoneLat`, `demoZoneLng`, `demoZoneRadiusMeters`, `perBusinessGeofence`. Add `defaultBusinessRadiusMeters = 200.0`.
  2. `lib/screens/shopper/roam_screen.dart`: Replace `demoZoneLat`/`demoZoneLng` usage with local municipal center `LatLng(10.7674886, 121.9428977)`.
  3. `lib/services/notification_service.dart`: Add `cancelAll()` to clear alerts on logout.
  4. `lib/services/data_service.dart`: Implement `fetchGeofenceZones()` querying verified businesses with at least one active promo, defaulting radius to 200m when null.
  5. `lib/services/geofence_service.dart`:
     - Dynamic `GeofenceZone` structure with `category`.
     - Refresh zones list on app start, after login, and every 10 minutes while service runs.
     - State tracking per business (`_inside`, `_lastEntered`, `_lastNotified`).
     - Check cooldown and shopper interest match (skip if interest list non-empty and does not match business category).
     - Notification title `"<business name> has a promo near you"` and body as best active promo title.
     - Implement `getNearestZone()` and unify `simulateEnter`/`simulateExit` to pass synthetic coordinates into `_handlePosition()`.
     - Logout stops service and cancels notifications via `NotificationService.instance.cancelAll()`.
  6. Shopper lifecycle & permissions:
     - `SplashScreen`, `LoginScreen`, `InterestsScreen`: Check permissions; if missing, route to `PermissionExplainerScreen`; if granted, start `GeofenceService.instance.start()`.
     - `PermissionExplainerScreen`: Start `GeofenceService` upon grant.
     - `AccountScreen`: Remove switch that turns alerts off.
     - `DashboardScreen`: Wire long-press MARK simulation sheet to nearest zone using `GeofenceService.instance`.
  7. Verification:
     - `flutter analyze`: Passed (0 issues).
     - `flutter test`: Passed (47/47 tests passed).
     - `flutter build apk --debug`: Built successfully (`build\app\outputs\flutter-apk\app-debug.apk`).
- **CHECKPOINT:** Phase 7B Completed.

---

### Phase 7C: Reverse Redemption Flow (Store Shows QR, Shopper Redeems)
**Goal:** Reverse the redemption flow so MSME merchants display a rotating QR and 8-character code, while shoppers redeem it using live camera scanning, gallery image upload, or manual code entry. Analytics continue recording real redemptions from `redeem_at_store`.

- **Key Tasks:**
  1. **Database Patch (`db/schema_patch_qr.sql`):**
     - Create private `app_secrets` table with RLS enabled and no public policies.
     - Implement `get_store_code(p_promo_id)`: callable by promo's business owner. Derives 8-character code and QR payload for current 60-second window using server-side secret. Returns remaining seconds and expiration.
     - Implement `redeem_at_store(p_code)`: callable by authenticated shopper. Validates code across current and previous window. Checks promo activity, dates, limit. Atomically creates/gets voucher, sets status `redeemed`, increments `promos.redeemed_count`, and logs `redeemed` event with business ID. Returns `ok`, `invalid`, `expired_code`, `already_redeemed`, `expired`, or `limit_reached`.
     - Preserves `redeem_voucher` in database unused; maintains strict RLS preventing shoppers from directly modifying `redemptions`.
  2. **DataService Updates (`lib/services/data_service.dart`):**
     - Add `getStoreCode(String promoId)`.
     - Add `redeemAtStore(String code)`.
     - Add `fetchTodayRedemptionsCount(String businessId, [String? promoId])`.
  3. **Merchant Side (`lib/screens/merchant/store_qr_screen.dart`):**
     - Replace `scan_screen.dart` with `store_qr_screen.dart` (`StoreQrScreen`).
     - Display large QR image via `QrImageView` and prominent 8-character code.
     - 60-second visible countdown timer with automatic code regeneration on expiry.
     - Promo selector dropdown/chips when multiple promos are active.
     - Live "redeemed today" counter.
     - Remove merchant camera scanner code.
     - In `promotions_screen.dart`: Rename "Scan QR" to "Show QR" (`Icons.qr_code_rounded`) and open `StoreQrScreen`.
  4. **Shopper Side (`lib/screens/shopper/redeem_store_screen.dart`):**
     - Implement "Redeem at store" screen reachable from `VoucherScreen` and `StashScreen`.
     - Option (a): Live camera scanner (`mobile_scanner`).
     - Option (b): Gallery image picker (`file_picker`) analyzed with `analyzeImage()`. Shows "No QR code found, try again" if unreadable.
     - Option (c): Manual 8-character text entry.
     - Camera permission fallback preserves upload and manual typing usability.
     - 1.5s debounce preventing double-submission.
     - Distinct result cards for `ok`, `invalid`, `expired_code`, `already_redeemed`, `expired`, `limit_reached`.
     - After `ok`, voucher screen updates status to `Redeemed`.
  5. **Tests & Verification:**
     - Update `test/scan_screen_test.dart` to test `StoreQrScreen` and `RedeemStoreScreen`.
     - Update `docs/demo_script.md` for reverse redemption flow.
     - Run `flutter analyze`, `flutter test`, `flutter build apk --debug`, and `flutter install --debug -d RFCY327KCFN`.

---

### Phase 8: UI Polish A — Merchant Registration & Dashboard
**Goal:** Align merchant multi-step registration and dashboard header with Stitch design frames (`market_msme_registration_step_2_business_information`, `market_tab_1_dashboard_immersive_scroll_header`), establish static media bucket and schema, ensure zero hardcoded fake content, and eliminate layout overflows across all screen sizes and text scaling factors.

- **Tasks:**
  1. **Database Schema Patch (`db/schema_patch_media.sql`):**
     - Add nullable `businesses.logo_url` and `businesses.interior_urls (text[])`.
     - Add nullable business hours columns (`open_days text[]`, `opens_at text`, `closes_at text`).
     - Create public-read storage bucket `business-media` with owner-only mutation RLS policies (`(storage.foldername(name))[1] = auth.uid()::text`). Keep `merchant-docs` private.
     - Document patch; do NOT apply to database.
  2. **Model & Service Updates:**
     - Update `Business` model with `logoUrl`, `interiorUrls`, `openDays`, `opensAt`, `closesAt`, JSON serialization, and dynamic `isOpenNow` / `openStatusText` helpers.
     - In `DataService`: add `uploadBusinessMedia` uploading to `business-media/<uid>/` returning public URL, and `updateBusinessDetails`.
  3. **Merchant Registration Controller & Steps:**
     - In `MerchantRegController`: manage picked images (`logoBytes`, `coverBytes`, `interiorImages`), upload state, and hours configuration. Ensure initial business fields start empty with zero hardcoded defaults.
     - In `RegStep2Screen`:
       - Match Stitch frame: business name, category chips (8 canonical slugs), shop bio with live `X / 250` counter.
       - Municipality dropdown, street address & barangay.
       - Hotline with reusable `CountrySelectorButton` (+63 default, stored as `+<code><number>` without leading 0).
       - Operating hours: day chips (M-S toggle), "Same hours daily" toggle, opens_at / closes_at with `showTimePicker`.
       - Store Photos & Branding: Logo (square), Exterior (16:9, required), Interior (up to 3, optional). File picker max 5MB validation.
     - In `RegStep4ReviewScreen`: Display logo, exterior photo, all business info, and full international phone number.
  4. **Merchant Dashboard:**
     - Immersive hero: business exterior photo (`coverUrl`) with dark bottom gradient, logo (`logoUrl`) as rounded avatar, business name, category, computed Open/Closed status pill. Category placeholder asset fallback (`assets/categories/{category}.png`).
     - Edit button opening business editing modal (name, bio, hours, photos, hotline).
     - Display only real data from `geofence_events` (views, claims, redemptions; 0 with short empty state).
     - Hide Best Sellers until products with best-seller flag exist; hide reviews card entirely.
     - "About Our Business" shows real bio and real hours.
  5. **Shopper Storefront & Roam:**
     - Storefront and Roam cards display the real logo and exterior photo with category asset fallback.
  6. **Layout Robustness & Overflow Verification:**
     - Eliminate fixed heights on text rows; use `Expanded`, `Flexible`, `Wrap`, and `softWrap: true`.
     - Ensure min 48x48 tap targets.
     - Widget tests verifying no `RenderFlex` overflow at 360x640 and 411x891 at font scales 1.0 and 1.5 in portrait and landscape.
  7. **Build & Device Verification:**
     - [x] Run `flutter analyze` (0 issues).
     - [x] Run `flutter test` (all 97 tests passed).
     - [x] Run `flutter build apk --debug` (built `build\app\outputs\flutter-apk\app-debug.apk` in 26.2s).
     - [x] Device install attempted: `flutter install --debug -d RFCY327KCFN` (device disconnected; builds verified).

---

### Phase 9: UI Polish B — Header & Nav Unification, Single Logo, Catalog Enhancements & Responsiveness
**Goal:** Establish unified `AppHeader` and `AppBottomNav`, single logo asset (`assets/logos/logo_icon.png`), merchant catalog products & promotions segmented tabs with category chips, availability/best-seller toggles, product image upload, relocate shopper debug panel to a long-press simulation sheet, and guarantee zero `RenderFlex` overflows at 360x640 and 411x891 at font scales 1.0 and 1.5.

- **Completed Tasks:**
  1. **Unified Header (`AppHeader`):**
     - Single logo icon (`assets/logos/logo_icon.png`, 28x28dp).
     - Dual-tone wordmark "MARK" (`primaryContainer`) + "et" (`onSurface`) with long-press gesture detector on "MARK".
     - Fixed height of 56dp, bounded safe area, and `MediaQuery.withClampedTextScaling(maxScaleFactor: 1.2)` protecting against header overflow on 360px wide devices at 1.5 text scale.
     - Subtitle slot with vertical divider (e.g., "Catalog", "Stash", "Analytics", "Store QR").
     - Right-side notification bell and optional trailing action button.
     - Optional back arrow button for detail screens.
  2. **Unified Bottom Navigation (`AppBottomNav`):**
     - Floating pill navigation bar for Shopper and Merchant roles with active tinting and safe-area padding.
  3. **Merchant Catalog Screen Enhancements (`catalog_screen.dart`):**
     - Products & Promotions segmented tabs displaying real count badges.
     - Dynamic category chips (`All Items` + merchant categories).
     - "Add Item" modal with photo picker, title, category, price, description, Best Seller toggle, and Available to Shoppers toggle.
     - Product image upload directly targeting `business-media/<uid>/products/`.
     - "New Promo" modal with promo type chips (BOGO, Percentage, Fixed Off, Free Item), title, terms, date pickers, and redeem limit.
     - Resilient loading state initializing `_isLoading = false` with graceful offline fallback.
  4. **Store QR & Scan Alignment (`store_qr_screen.dart`):**
     - Display merchant business identity name and storefront icon in checkout content.
     - Resilient initial load initializing promo details synchronously in `initState`.
  5. **Shopper Dashboard Simulation Sheet:**
     - Removed on-screen debug launcher; relocated simulation panel to a clean bottom sheet triggered by long-pressing "MARK".
  6. **Zero Overflow Verification:**
     - `StatusPill`: wrapped text in `Flexible` with `TextOverflow.ellipsis`, eliminating horizontal overflow in constrained containers.
     - `MerchantDashboardScreen`: wrapped store name and category in `Wrap`, eliminating 75px and 24px overflows at 1.5 scale.
     - All 36 responsive layout and overflow test configurations passed cleanly across 360x640, 411x891, 640x360, 891x411 at scales 1.0 and 1.5.
  7. **Build & Test Verification:**
     - [x] `flutter test`: 97/97 tests passed across all 6 test suites.
     - [x] `flutter analyze`: 0 issues found (clean static analysis).
     - [x] `flutter build apk --debug`: Built `build\app\outputs\flutter-apk\app-debug.apk` in 22.9s.

---

### Phase 10: Promo Photos — Database, Merchant Catalog, Shopper Screens & Big-Picture Notifications
**Goal:** Add required promo photo to promotions, display promo photos across merchant and shopper surfaces with graceful fallbacks, and attach promo photos to geofence notifications using `flutter_local_notifications` BigPictureStyle with resilient background caching.

- **Tasks:**
  1. **Database Schema Patch (`db/schema_patch_media.sql`):**
     - Add `alter table promos add column if not exists image_url text;`.
     - Confirm storage policy `(storage.foldername(name))[1] = auth.uid()::text` permits owner upload, update, and delete in `business-media/<uid>/promos/`.
     - Do NOT apply automatically.
  2. **Model & Service Updates:**
     - Update `Promo` model with `imageUrl`, `fromJson`, `toJson`, `copyWith`.
     - In `DataService`: add `uploadPromoImage` uploading to `business-media/<uid>/promos/` with public URL. Pass `promoImageUrl` in `fetchGeofenceZones()`.
     - Update `GeofenceZone` to hold `promoImageUrl`.
  3. **Promo Image Cache & Notification Service:**
     - Add `path_provider` for app cache directory.
     - Create `PromoImageCacheService` using `dart:io HttpClient` (5s timeout, 2MB size cap, cache by `promoId`, pre-download on zone refresh, prune stale promo images).
     - Update `NotificationService.instance.showPromo` to support `imagePath`, constructing `BigPictureStyleInformation(FilePathAndroidBitmap(imagePath), contentTitle: title, summaryText: body, hideExpandedLargeIcon: true)` with text fallback.
  4. **Merchant Side:**
     - In `MerchantCatalogScreen._openAddOrEditPromoModal`:
       - Add required "Promo photo" field above title.
       - Pick using `file_picker` (jpg/png/webp, max 2MB validation error).
       - Preview with "Replace" and "Remove" actions.
       - Form state persistence for picked bytes.
       - Block save with "Add a photo for this promo" if missing.
       - Upload to `business-media/<uid>/promos/` with progress and retry.
     - Promo cards in `catalog_screen.dart` and `dashboard_screen.dart` show photo with fallback to business cover, then category placeholder.
  5. **Shopper Side:**
     - Promo cards on dashboard (`dashboard_screen.dart`).
     - Promo detail header image (`promo_detail_screen.dart`).
     - Stash cards (`stash_screen.dart`).
     - Redeem store result card (`redeem_store_screen.dart`).
     - Fallback chain: promo image -> business cover -> category placeholder asset. Loading and error placeholders.
  6. **Tests & Delivery:**
     - Unit & widget tests for promo photo validation, >2MB rejection, BigPicture notification construction and download fallback.
     - Run `flutter analyze`, `flutter test`, `flutter build apk --debug`, and `flutter install --debug -d RFCY327KCFN`.

---

### Phase 11: In-App AI Assistant for Shoppers and MSME Owners (Google Gemini)
**Goal:** Add an agentic in-app AI assistant for shoppers and MSME merchants using the Google Gemini API (free tier) via a Supabase Edge Function (`supabase/functions/chat/index.ts`). The model proposes actions, but the app executes them only after explicit user confirmation.

- **Tasks:**
  1. [x] **Database Schema Patch (`db/schema_patch_ai.sql`):**
     - Created table `ai_usage(id bigserial primary key, user_id uuid references auth.users(id), created_at timestamptz default now())`.
     - Enabled RLS with policies for insert and select where `user_id = auth.uid()`.
     - Added index on `(user_id, created_at desc)`.
     - Preserved unapplied: left for manual application in Supabase SQL editor.
  2. [x] **Supabase Edge Function (`supabase/functions/chat/index.ts`):**
     - Validates caller JWT via `supabase.auth.getUser()`, rejects anonymous requests.
     - Reads role securely from `public.profiles` using caller's Authorization header.
     - Constant `GEMINI_MODEL = "gemini-3.8-flash"` configured at top.
     - Communicates with Google Generative AI REST API with secret `GEMINI_API_KEY` in `x-goog-api-key` header.
     - Hourly rate limit (20 requests/user/hour) tracked in `public.ai_usage`.
     - Defensive error handling: safety blocks/missing candidates -> friendly message, 429 -> "busy, try again in a minute", 5xx -> generic error.
     - Shopper context: up to 15 valid promos, interests, stashed IDs, device distances (never coordinates). Tools: `open_promo`, `open_store`, `propose_save_to_stash`.
     - Merchant context: business profile (no phone/owner), products, promos, 7-day funnel counts, verification status. Tools: `propose_promo`, `propose_product`, `pause_promo`.
     - Server-side tool validation: title <= 60 chars, description <= 200 chars, promo_type in ('bogo','percent','amount_off'), duration <= 90 days, limit 1..1000, price >= 0, caller owns verified business.
  3. [x] **Flutter Models & Chat Service:**
     - `lib/models/chat.dart`: `ChatMessage`, `AssistantAction`, `MessageSegment`, and `parseDraftBlocks`.
     - `lib/services/chat_service.dart`: Edge Function invocation, device distance calculation, error mapping, and injectable `FunctionInvoker`.
  4. [x] **Chat UI & Actions (`lib/screens/shared/assistant_screen.dart`):**
     - AppHeader(subtitle: 'Assistant', showBack: true).
     - Message bubbles, typing indicator, error retry bar, "New chat" action.
     - Suggestion chips for Shopper & Merchant empty states.
     - Draft cards with 1-tap Copy action.
     - Action confirmation cards: explicit user tap required; pre-fills existing promo/product modals or confirms stash/pause.
  5. [x] **Entry Points & Catalog Integration:**
     - Assistant FAB on Shopper Dashboard (`dashboard_screen.dart`) elevated above AppBottomNav.
     - Assistant FAB on Merchant Dashboard (`dashboard_screen.dart`) elevated above AppBottomNav.
     - Help & Assistant row on Merchant Account Screen (`account_screen.dart`).
     - Added `PromoDraft`, `ProductDraft`, prefilling, and "Use My Shop Photo" option to `MerchantCatalogScreen`.
  6. [x] **Documentation & Tests:**
     - `docs/ai_assistant_setup.md` manual checklist and test cases.
     - Created `test/ai_assistant_test.dart` (20 tests passed) covering ChatService, error mapping, action parsing, draft parsing, explicit confirmation, and zero overflow at 360x640 and 411x891 across 1.0 and 1.5 font scales.
     - `flutter analyze`: 0 issues found.
     - `flutter test`: 123/123 tests passed across all 7 test suites.
     - `flutter build apk --debug`: Built `build\app\outputs\flutter-apk\app-debug.apk` in 22.8s.
     - `flutter install --debug -d RFCY327KCFN`: Target device RFCY327KCFN disconnected/not detected.

---

### Phase 11 Refinement: AI Assistant Reply Polishing & Clean Presentation
**Goal:** Eliminate raw markdown, internal UUIDs, leaking tool calls, and unexpected draft card wrappings from AI assistant replies. Add compact tappable promo suggestion cards, friendly action confirmation cards, and comprehensive client-side and server-side text sanitization.

- **Tasks:**
  1. **Edge Function (supabase/functions/chat/index.ts):**
     - Update system prompt: plain text only (no markdown emphasis **, __, , no # headings, no tables).
     - Bullet lines use • , numbered steps use 1., 2..
     - Promos formatted as Business name (about 200 m away) - Promo title: value (distances in m under 1000, km above).
     - Never output IDs, UUIDs, function calls, or Propose Actions in reply text.
     - :::draft blocks strictly limited to user requests to write copy.
     - Server-side clean-up: strip markdown characters, strip UUIDs, remove lines matching function call syntax or Propose Actions.
     - Enrich action with human-friendly metadata (title, business_name, value_label).
     - Return suggested_promos array containing structured promo metadata.
  2. **Data Models & Sanitizer (lib/models/chat.dart):**
     - Add SuggestedPromo model (id, title, businessName, value, distance).
     - Add suggestedPromos field to ChatMessage.
     - Add client-side sanitizeAssistantReply(String text): strips **, __, , leading #, UUIDs, function calls, and Propose Actions; converts *  and -  to • ; collapses >2 blank lines; trims trailing spaces; protects draft block text while stripping emphasis characters.
     - Automatically sanitize assistant chat message content.
  3. **Chat Service (lib/services/chat_service.dart):**
     - Parse suggested_promos and pass to ChatMessage.
  4. **Chat UI (lib/screens/shared/assistant_screen.dart):**
     - Normal answers rendered via SelectableText with paragraph spacing, never wrapped in Drafted Content cards.
     - Only genuine :::draft ... ::: blocks render _buildDraftCard.
     - Render compact tappable promo suggestion cards with business name, title, value, distance, navigating to PromoDetailScreen. Never expose IDs.
     - Action confirm cards display friendly titles and descriptions without IDs or function names.
     - Prevent RenderFlex overflow at 360x640 and 411x891 at 1.0 and 1.5 scales.
  5. **Tests & Verification (test/ai_assistant_test.dart):**
     - Unit tests verifying sanitization rules, bullet conversions, draft preservation.
     - Widget tests verifying plain answers do not show Draft card, and promo suggestion cards do not show IDs.
     - Responsive tests for small screens and high text scales.
     - Full verification with flutter analyze, flutter test, and flutter build apk --debug.

---

### Phase 12: Replace Flutter Logo with MARKet Logo & App Branding

**Goal:** Replace every default Flutter icon/logo with the official MARKet logo (assets/logos/logo_icon.png) across Android launcher icons (legacy, round, adaptive), notification status bar silhouettes, foreground location service notification, and verify app branding.

- **Tasks:**
  1. **Generate Logo & Notification Assets:**
     - Save `assets/logos/logo_icon_transparent.png` (transparent background version of the logo).
     - Save `assets/logos/logo_icon_foreground.png` (transparent 1024x1024 canvas, logo scaled to 60% of canvas, centered).
     - Save `assets/logos/logo_icon_legacy.png` (1024x1024 solid white background `#FFFFFF` with 15% margin, centered).
     - Generate white-on-transparent silhouette notification icons `ic_stat_market.png` across all drawable densities:
       - `drawable-mdpi/ic_stat_market.png` (24x24 px)
       - `drawable-hdpi/ic_stat_market.png` (36x36 px)
       - `drawable-xhdpi/ic_stat_market.png` (48x48 px)
       - `drawable-xxhdpi/ic_stat_market.png` (72x72 px)
       - `drawable-xxxhdpi/ic_stat_market.png` (96x96 px)
  2. **Launcher Icon Generation:**
     - Add `flutter_launcher_icons: ^0.14.4` to `dev_dependencies` in `pubspec.yaml`.
     - Configure `flutter_launcher_icons` with white adaptive background `#FFFFFF`, foreground image, and legacy image.
     - Run `dart run flutter_launcher_icons` to replace all default Flutter icons in `res/mipmap-*` and generate adaptive XML and round icons.
  3. **App Name & Manifest:**
     - Verify `android:label="MARKet"` in `android/app/src/main/AndroidManifest.xml`.
     - Ensure round icon `android:roundIcon="@mipmap/ic_launcher_round"` is declared.
  4. **Notification Service & Geofence Service:**
     - Update `lib/services/notification_service.dart` to use `@drawable/ic_stat_market` for initialization and promo notification details (`smallIcon`/`icon`).
     - Update `lib/services/geofence_service.dart` `ForegroundNotificationConfig` to use `AndroidResource(name: 'ic_stat_market', defType: 'drawable')`.
     - Verify big-picture promo notification continues to work.
  5. **Leftover Branding Audit & Native Splash:**
     - Inspect `android/`, `lib/`, `pubspec.yaml` for any leftover Flutter logos or `ic_launcher` references.
     - Confirm native `launch_background.xml` has no default Flutter icons.
  6. **Tests & Verification:**
     - Verify file sizes and visual recognition of silhouette at 24px-96px.
     - Unit test notification icon configuration.
     - Execute `flutter analyze`, `flutter test`, `flutter build apk --debug`, and `flutter install --debug -d RFCY327KCFN`.

---

### Phase 13: Fix Promo Timezone Offset (Asia/Manila UTC+8) & Immediate Start Defaults

**Goal:** Ensure promo `starts_at` and `ends_at` are created as local DateTime objects from date/time pickers and converted with `.toUtc()` before `.toIso8601String()`, defaulting new promos to "now" so they are live immediately. In `chat/index.ts`, normalize model-returned dates to Asia/Manila (+08:00) and update the system prompt. On reading, parse with `DateTime.parse(...).toLocal()` before displaying or computing live/expired badges.

- **Tasks:**
  1. **Edge Function `chat/index.ts`:**
     - Update system prompt to instruct model that promo dates (`starts_at`, `ends_at`) must be formatted as ISO-8601 strings in Asia/Manila with `+08:00` offset, and `starts_at` defaults to current time (${manilaTime}) rather than a fixed 9 AM.
     - In tool parameters for `propose_promo`, document `+08:00` format in Asia/Manila time.
     - When receiving `propose_promo` tool calls, treat dates as Asia/Manila, stripping naive/Z representation and appending `+08:00` before returning in proposed action.
  2. **Merchant New/Edit Promo Modal (`catalog_screen.dart`):**
     - Default new promo start time to "now" (`DateTime.now()`), not fixed 9 AM.
     - Default new promo end time to 7 days ahead end-of-day.
     - Ensure date/time picker builds local `DateTime(y, m, d, h, min)` and converts with `.toUtc()` on save.
     - Display live/expired/scheduled status badge using local time.
  3. **DataService (`data_service.dart`):**
     - In `createPromo` and `updatePromo`, ensure `starts_at` and `ends_at` are serialized to UTC strings ending in `Z`.
  4. **AI Assistant Screen (`assistant_screen.dart`):**
     - In `_handleActionConfirm`, parse incoming `starts_at` and `ends_at` with `.toLocal()` before constructing `PromoDraft`.
     - In `_buildActionProposalCard`, parse dates with `.toLocal()` when displaying draft validity.
  5. **Promo Model & Badge Computations (`promo.dart`, `stash_screen.dart`, etc.):**
     - In `Promo`, ensure validity check compares local or UTC properly and handles `.toLocal()` consistently.
     - In `stash_screen.dart` and `promo_detail_screen.dart`, ensure `ends_at` and `starts_at` are converted `.toLocal()`.
  6. **Unit Tests (`test/models_test.dart`):**
     - Test: Promo created for `2026-10-13 09:00` local Manila time produces `starts_at = 2026-10-13T01:00:00Z`.
     - Test: End date of `23:59:59` local Manila time becomes `15:59:59Z`.
     - Run `flutter analyze` and `flutter test`.

---

### Phase 14: Static Store QR Code Extraction & Scanner Overflow Fix

**Goal:** Fix the bug where scanning the merchant's static QR code sends raw JSON `{"APP":"MARKET","CODE":"..."}` to `redeem_at_store` (causing "Invalid Store Code") and overflows the result card by ~1494px.

- **Tasks:**
  1. **Shared Helper `extractStoreCode(String raw)`:**
     - Trim and uppercase input.
     - If it starts with `{`, decode JSON and extract `CODE` field case-insensitively.
     - Otherwise treat as plain code.
     - Strip spaces and dashes; reject anything that is not 8 alphanumeric characters (`^[A-Z0-9]{8}$`).
     - On failure, return `null`.
     - In UI, show `"This QR isn't a MARKet store code"` without calling server.
  2. **Server RPC Calling:**
     - Both QR scan and manual submit extract code first and pass only the 8-character extracted code to `redeem_at_store`.
     - `DataService.redeemAtStore` normalizes input with `extractStoreCode` as defense-in-depth.
  3. **Result Card Overflow-Proofing:**
     - Display only the extracted 8-character code with `maxLines: 1`, `overflow: TextOverflow.ellipsis`, and wrapped in `Flexible` + `FittedBox(fit: BoxFit.scaleDown)`.
  4. **Merchant QR Encoding:**
     - In `StoreQrScreen`, encode the plain 8-character code in `QrImageView`, while keeping `extractStoreCode` tolerant of JSON payloads.
  5. **Camera Lifecycle & Debounce:**
     - Debounce scan events so one scan executes exactly one RPC call.
     - Stop camera controller immediately after obtaining a redemption result; restart when tapping "Try Again" or switching back to Camera tab.
  6. **Unit & Widget Tests:**
     - Test `extractStoreCode` with plain code, lowercase code, JSON payload, JSON with extra fields, garbage text, and wrong length.
     - Test `RedeemStoreScreen` scanning JSON payload, verifying RPC parameter and result card rendering without overflow.
     - Test `RedeemStoreScreen` scanning invalid QR code, showing error banner without calling server.

---

### Phase 15: Fix Promo Picker Timezone Offset & Start Time Clamping

**Goal:** Fix the bug where promo start/end times created via date/time pickers are stored 8 hours late (e.g. 10:00 AM Manila stored as 10:00:00+00 instead of 02:00:00+00). Ensure picker values are built as local `DateTime(y, m, d, h, min)` and converted to UTC `.toUtc().toIso8601String()`. Parse with `DateTime.parse(...).toLocal()` when loading promos in Edit modal and displaying them. Clamp start times earlier than now on today's date to `now` for immediate live status. Display merchant promo status chip computed from starts_at/ends_at (Upcoming / Live / Ended).

- **Tasks:**
  1. **Date/Time Picker Local Construction & Clamping (`catalog_screen.dart`):**
     - Ensure `_pickDateTime` constructs a local `DateTime(year, month, day, hour, minute)`.
     - In `_openAddOrEditPromoModal`, when user selects a start time earlier than `now` on today's date, clamp `startsAt` to `now`.
     - When saving new promo or editing promo, clamp `startsAt` to `now` if today and in past, then convert to UTC before sending to `DataService`.
     - When loading existing promo into Edit modal, parse with `.toLocal()`.
  2. **DataService Clamping & Serialization (`data_service.dart`):**
     - In `createPromo` and `updatePromo`, clamp start time earlier than now today to `now`, serialize to UTC ISO-8601 string ending in `Z`.
  3. **Promo Model Parsing (`promo.dart`):**
     - In `Promo.fromJson`, parse `starts_at` and `ends_at` with `DateTime.parse(...).toLocal()`.
     - Keep `toJson` converting to UTC.
  4. **Merchant Promo List Status Chip (`catalog_screen.dart`):**
     - Update `_buildPromoStatusBadge` to display clear chips computed from `starts_at`/`ends_at`:
       - `UPCOMING • Starts ...` (blue badge)
       - `LIVE • Ends in ...` (green badge)
       - `ENDED • Expired / Paused / Limit Reached` (gray badge)
  5. **Unit Tests (`test/models_test.dart`):**
     - Test: Picking 2026-10-13 10:00 local Manila produces `starts_at = 2026-10-13T02:00:00Z`.
     - Test: Picking end 21:00 local Manila produces `ends_at = 2026-10-13T13:00:00Z`.
     - Test: Clamping start times earlier than now today to `now`.
     - Test: Round-trip JSON deserialization with `.toLocal()`.


