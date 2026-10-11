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
- **CHECKPOINT:** Stop after Phase 2 and wait for user review before proceeding.

---

### Phase 3: Shared Authentication, Onboarding & Explainer
**Goal:** Implement Splash, Role Selection, Login (with demo shortcuts), and Permission Explainer screens.
- **Files to create:**
  - `lib/screens/shared/splash_screen.dart` — 2s splash, checks session -> routes to Shopper Dashboard, Merchant Dashboard (if verified), Merchant Waiting (if unverified), Merchant Reg Step 2 (if profile exists but no business), or Role Selection.
  - `lib/screens/shared/role_selection_screen.dart` — Matches `market_role_selection` frame.
  - `lib/screens/shared/login_screen.dart` — Email/password login + one-tap "Demo Shopper" and "Demo Merchant" buttons (shown when `demoMode = true`).
  - `lib/screens/shared/permission_explainer_screen.dart` — 3-point explainer before requesting location & notification permissions.
- **Acceptance Checks:**
  - Splash routes correctly based on user role and business registration state.
  - Demo login buttons instantly log into pre-seeded accounts.
  - `flutter analyze` passes.

---

### Phase 4: Shopper Screens & Hyperlocal Demo Loop
**Goal:** Implement full shopper experience: OTP registration modal, canonical interest grid, dashboard with long-press MARK simulate trigger, real OSM map discovery with fallback, Stash, QR voucher screen, and Account.
- **Files to create:**
  - `lib/screens/shopper/register_screen.dart` — Form + bottom sheet OTP modal ("Demo code: 123456").
  - `lib/screens/shopper/interests_screen.dart` — Grid from 8 canonical category slugs.
  - `lib/screens/shopper/dashboard_screen.dart` — Recommendations, featured promos. Long-press "MARK" logo opens sheet with "Simulate entering zone".
  - `lib/screens/shopper/roam_screen.dart` — `flutter_map` + OSM tiles, 1500m zone circle, business markers, bottom sheet, auto-switch to List view if tiles fail repeatedly.
  - `lib/screens/shopper/storefront_screen.dart` — Storefront details, cover image / category fallback, active promos with Save button.
  - `lib/screens/shopper/promo_detail_screen.dart` — Opened by notification tap or browse. Logs `viewed`/`opened` events. "Save to Stash" & "Get Voucher".
  - `lib/screens/shopper/stash_screen.dart` — Saved promos tabs (All/Active/Expiring/Expired), "Open Voucher" action.
  - `lib/screens/shopper/voucher_screen.dart` — Generates 8-char code & QR via `qr_flutter`. Issues `redemptions` row and logs `claimed` on first open.
  - `lib/screens/shopper/account_screen.dart` — Canonical interest chips, live permission status, notification toggles, logout.
- **Acceptance Checks:**
  - Simulating zone entry triggers local notification.
  - Notification tap navigates to `promo_detail_screen.dart` and logs `opened` event.
  - Saving promo writes to `stash` only.
  - Opening voucher issues `redemptions` row and logs `claimed` event.
  - `flutter analyze` passes.

---

### Phase 5: MSME Merchant Portal & QR Redemption
**Goal:** Implement 4-step merchant registration with resume capability, 10s auto-verification, Dashboard, Catalog & Promos CRUD, QR Scanner calling `redeem_voucher` RPC, and Analytics.
- **Files to create:**
  - `lib/screens/merchant/reg_step1_screen.dart` — Owner details + demo OTP.
  - `lib/screens/merchant/reg_step2_screen.dart` — Business info, category mapping, lat/lng defaulting to Kape Tahanan. Resume entrypoint if uncompleted.
  - `lib/screens/merchant/reg_step3_screen.dart` — Document uploads to Supabase Storage `merchant-docs/<uid>/`.
  - `lib/screens/merchant/reg_step4_review_screen.dart` — Summary review & submit unverified business.
  - `lib/screens/merchant/waiting_screen.dart` — 10s auto-verify timer updating `businesses.verified = true`.
  - `lib/screens/merchant/verified_screen.dart` — Feature unlocked celebration.
  - `lib/screens/merchant/dashboard_screen.dart` — Immersive header, store status, performance stats, quick promo button.
  - `lib/screens/merchant/catalog_screen.dart` — Products list + Add Item modal.
  - `lib/screens/merchant/promotions_screen.dart` — Promos list + Create Promo modal + "Scan QR" button.
  - `lib/screens/merchant/scan_screen.dart` — `mobile_scanner` + manual code input. Invokes `rpc('redeem_voucher', params: {'p_code': code})`. Displays atomic result states.
  - `lib/screens/merchant/analytics_screen.dart` — 7-day conversion funnel from `geofence_events` with static/fallback numbers.
  - `lib/screens/merchant/account_screen.dart` — Business profile, permit checklist, alert toggles, logout.
- **Acceptance Checks:**
  - Resuming registration re-populates state in Step 2 via `MerchantRegController`.
  - QR Scanner validates code via `redeem_voucher` RPC and shows correct result (`ok`, `already_redeemed`, `expired`, etc.).
  - Analytics reflect updated redemption metric.
  - `flutter analyze` passes.

---

### Phase 6: End-to-End Integration & Final Acceptance Gate
**Goal:** Verify entire demo loop, terminal analysis, and compile final debug APK.
- **Terminal Verification:**
  - `flutter pub get`
  - `flutter analyze` (0 errors, 0 warnings)
  - `flutter build apk --debug`
- **End-to-End Demo Script:**
  1. Launch app -> Tap "Demo Shopper" one-tap login.
  2. Long press "MARK" header logo -> tap "Simulate entering zone".
  3. Confirm local notification appears: `"Promos near you in San Jose"`.
  4. Tap notification -> opens Promo Detail for Kape Tahanan BOGO.
  5. Tap "Get Voucher" -> QR Voucher opens with 8-character code.
  6. Logout to Role Selection / Login -> Tap "Demo Merchant (Kape Tahanan)" one-tap login.
  7. Navigate to Promotions -> tap "Scan QR".
  8. Scan shopper QR voucher (or enter 8-character code) -> verify atomic redemption succeeds (`ok`).
  9. Attempt to scan the same voucher again -> verify error (`already_redeemed`).
  10. Navigate to Merchant Analytics -> verify 7-day funnel reflects the new redemption.
