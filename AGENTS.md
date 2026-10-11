# Agent Directives (v3.0) — MARKet (Flutter + Supabase)

Hackathon app: hyperlocal MSME promo discovery for San Jose de Buenavista, Antique (PH).
Two roles: Shopper, MSME Merchant. Core feature: from-scratch geofence that fires a local
notification with a promo when a logged-in shopper enters the San Jose zone, even when the app
is minimized or the screen is off.

## 1. Read order (before ANY code)
1. `AGENTS.md` (this file)
2. `specs/00-overview.md` → `specs/01-screens-and-flow.md` → `specs/02-database.md` →
   `specs/03-geofence.md` → `specs/04-demo-shortcuts.md`
3. `design/DESIGN.md` (design tokens) and `design/stitch_msme_promo_mobile_dashboard/*/screen.png`
   + `code.html` (visual reference per screen)
4. `db/schema.sql`, `db/seed.sql`
5. `reference/geofence/` (working starter code for the geofence + notifications)
If specs and this file conflict, `specs/` wins on product behavior, this file wins on process.

## 2. Operating layers
- **L1 Intent:** `specs/` — what to build.
- **L2 Plan:** `implementation_plan.md` — write/update BEFORE any change touching >2 files.
- **L3 Execute:** small atomic diffs, verify after each.

## 3. Behavior rules (kept from v2, adapted to Flutter)

### A. Minimalism (Ponytail)
- Smallest code that meets the spec. No premature abstraction, no wrapper files, no repository
  layers beyond what `specs/` names.
- **Dependency allowlist (these are pre-approved; anything else needs my OK):**
  `supabase_flutter`, `geolocator`, `permission_handler`, `flutter_local_notifications`,
  `flutter_map`, `latlong2`, `qr_flutter`, `mobile_scanner`, `file_picker`, `google_fonts`.
- State management: built-in only (`ChangeNotifier` + `ListenableBuilder`/`ValueNotifier`).
  Navigation: built-in `Navigator` with named routes + one global `navigatorKey`.
- **No paid or billing-required APIs.** No Google Maps, no Twilio/SMS, no paid geofencing SDKs
  (e.g. `flutter_background_geolocation` release license). Geofence logic is our own code.

### B. Design fidelity (Impeccable)
- The look is **already decided** by Stitch. Do NOT invent a new aesthetic. Pull colors,
  type scale (Plus Jakarta Sans), radii and spacing from `design/DESIGN.md` into one
  `lib/core/theme.dart`. Match each `screen.png` layout; use `code.html` for exact copy,
  icon names and structure.
- Every tappable element: pressed + disabled states, min 48×48 dp target, readable contrast.
- Every list/screen: loading state, empty state, error state.
- Ban: default Material blue look, generic gradient backgrounds, unstyled `AppBar`/`Scaffold`
  defaults that contradict the design.
- For screens with no frame: reuse the same components/tokens; do not introduce new styles.

### C. Lean communication (Caveman)
- Terse status updates. No pleasantries. Code, paths, commands, SQL: exact and complete.
- But: always state clearly (1) what changed, (2) what you verified, (3) what you could NOT
  verify. Do not hide blockers to stay short.

### D. Impact tracing (Graphify)
- Before refactors, trace who imports/uses the thing. Do not scan the whole repo for small edits.

### E. Visual architecture (Archify)
- Before Phase 1 and before the schema is applied, produce one diagram (HTML or Mermaid) of:
  screen flow per role, and ERD. Save in `docs/`. Do not block on polish.

### F. Lifecycle engineering (Addy Osmani)
- Single responsibility per file. Unidirectional data flow. Cancel every `StreamSubscription`,
  timer and controller in `dispose`. No work in `build()`. Keep animations at 60fps.

### G. Verification (Superpowers)
- After edits run: `flutter pub get` (if deps changed), `flutter analyze`, `flutter test`
  (if tests exist), and `flutter build apk --debug` at the end of every phase.
- Never say "done" unless these succeed. Paste failures verbatim.
- **Device-only features** (background location, notifications while locked, QR camera, permission
  dialogs) CANNOT be verified in a terminal. For these, say "builds OK — needs on-device test"
  and list the exact manual test steps. Never claim they work.

## 4. Non-negotiable product rules
- Platform: **Android only** for the demo. Skip iOS config.
- Backend: **Supabase** (Postgres + Auth + Storage), free tier. Client uses the **anon key only**.
  Never put the `service_role` key in the app. Config lives in `lib/core/env.dart`.
- Geofence = own distance check (`Geolocator.distanceBetween`) on a position stream running as a
  foreground service. Notifications = `flutter_local_notifications`. No push/FCM.
- Demo shortcuts in `specs/04-demo-shortcuts.md` are REQUIRED features, not shortcuts to remove.
- Do not add features, screens or packages not in `specs/` without asking.
- Seed/sample data is Philippine (₱, Antique, San Jose de Buenavista). Keep copy from the frames.

## 5. Self-annealing
On build/test/runtime error: read the stack trace → minimal fix at the failing line → re-run the
same command → if it was a recurring/surprising issue, add one line under Known Quirks.
Never regenerate whole files to fix one error.

## 6. Directory layout
```
AGENTS.md
implementation_plan.md        # agent-maintained roadmap + checkpoints
specs/                        # product intent (read-only unless I say so)
design/                       # DESIGN.md + extracted Stitch export (read-only reference)
db/schema.sql, db/seed.sql    # run in Supabase SQL editor
reference/geofence/           # starter geofence + notification code (copy into lib/, then adapt)
docs/                         # diagrams the agent generates
lib/
  main.dart
  core/        theme.dart, env.dart, config.dart (flags + demo zone), supabase.dart
  models/      profile, business, product, promo, redemption
  services/    auth_service, geofence_service, notification_service, data_service
  screens/
    shared/    splash, role_selection, login, permission_explainer
    shopper/   register, interests, dashboard, roam, stash, account, storefront, promo_detail, voucher
    merchant/  reg_step1..4, waiting, verified, dashboard, catalog, promotions, promo_form,
               scan, analytics, account
  widgets/     only reusable components used 2+ times
```

## 7. Known Quirks (pre-filled — append new ones)
- `flutter_local_notifications` needs core library desugaring + minSdk ≥ 21
  (see `reference/geofence/build_gradle_notes.txt`).
- Android 13+: runtime `POST_NOTIFICATIONS` permission required.
- Background location is a 2-step grant: while-in-use first, then "Allow all the time"
  (`Permission.locationAlways`). Android 11+ sends the user to Settings for the second step.
- Android 14+: foreground service type `location` required; keep
  `FOREGROUND_SERVICE_LOCATION` permission in the manifest.
- Tracking stops if the user swipes the app away or the OEM kills it (Xiaomi/Oppo/Vivo/Samsung
  battery optimization). Demo phone: disable battery optimization for the app, do not swipe away.
- First position update while already inside the zone counts as an "enter" (intended).
- Supabase free projects can pause when idle: open the dashboard before the demo.
- Supabase Auth: email confirmation must be OFF for the demo or sign-up won't return a session.
- `flutter_map` with OSM tiles needs internet and a `userAgentPackageName`.
