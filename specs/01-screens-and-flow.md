# 01 — Screens & Flow

Frame folder = `design/stitch_msme_promo_mobile_dashboard/<folder>/` (has `screen.png` + `code.html`).
**Match the frame. Use real data from Supabase where the frame shows sample data.**

## Shared
| Screen | Frame folder | Notes |
|---|---|---|
| Splash | `market_splash_screen` | 2s → session? role home : role selection |
| Role selection | `market_role_selection` | Merchant / Shopper cards; "Log In" link |
| Login | **NO FRAME** | Email + password, same style as registration inputs. Routes by `profiles.role`. Error text on failure. |
| Permission explainer | **NO FRAME** | Before requesting "Allow all the time": 3 short points (why location, why always, notifications). Buttons: "Allow", "Not now". Shown once, after first login. |

## Shopper flow
Role selection → Registration → Interest selection → Dashboard (tabs: Dashboard, Roam, Stash, Account)

| Screen | Frame folder | Behavior |
|---|---|---|
| Registration | `market_consumer_registration` | Step 1 of 2 basic profile. Mobile OTP = demo code (04). Gov ID upload optional (skippable, never blocks). Creates auth user + `profiles` row (role=shopper). |
| Interests | `market_consumer_interest_selection_mobile` | Multi-select, saved to `profiles.interests` (slugs below). "Skip for now" allowed. |
| Dashboard | `market_consumer_dashboard` | Category chips filter; "Businesses for You" (interest-matched), Popular, Featured Promotions. Distance = from last known position (fallback: demo zone center). Long-press the "MARK" header logo → **Simulate entering zone** (04). |
| Roam | `market_consumer_roam_map_discovery` | REAL map (flutter_map+OSM). Markers = verified businesses; user marker; draw the demo zone circle. Map/List toggle. Bottom sheet card per selected business. Filters All/Cafés/Food/Retail/Services. |
| Stash | `market_consumer_stash_saved_promotions` | From `stash`. Tabs All/Active/Expiring/Expired by `promos.ends_at`. "Open Voucher" → Voucher screen. Empty state included in frame. |
| Account & prefs | `market_consumer_account_preferences` | Profile, interests edit, location status (live permission state + "Manage App Permissions" → `openAppSettings()`), notification toggles (stored in profiles.prefs jsonb), Logout. |
| Storefront | **NO FRAME** | Business header (name, category, rating placeholder, hours, address), products list, active promos with Save button. Reuse dashboard card + catalog row styles. |
| Promo detail | **NO FRAME** | Opened by notification tap and "Details". Title, business, validity, terms, **Save to Stash** and **Get Voucher**. Logs `viewed` / `opened` events. |
| Voucher | **NO FRAME** (button in Stash) | Big QR of `redemptions.code`, promo + business name, status (Issued/Redeemed). Creates the `redemptions` row on first open. |

## Merchant flow
Role selection → Reg step 1 → 2 → 3 → (Review) → Waiting (auto 10s) → Verified → Dashboard (tabs: Dashboard, Catalog, Analytics, Account)

| Screen | Frame folder | Behavior |
|---|---|---|
| Reg 1 Basics | `market_msme_registration_step_1_basics` | Owner details. OTP = demo code. Creates auth user + profile (role=merchant). |
| Reg 2 Business | `market_msme_registration_step_2_business_information` | Business name, category, bio, municipality, address, phone, hours. Also **lat/lng**: button "Use my current location" (default fallback = demo shop coordinates `demoShopLat/demoShopLng` from config, NOT the zone center). |
| Reg 3 Permits | `market_msme_registration_step_3_business_verification` | 4 uploads → Storage bucket `merchant-docs/<uid>/`. If upload fails or file skipped, continue anyway (demo). |
| Reg 4 Review | **NO FRAME** | Summary of steps 1–3 + Submit. Creates `businesses` row (verified=false). |
| Waiting | `market_waiting_for_verification` | After `demoAutoVerifySeconds` auto-set `verified=true` and go to Verified. |
| Verified | `market_verified_page_mobile` | "Proceed to dashboard". |
| Dashboard | `market_tab_1_dashboard_immersive_scroll_header` | Real counts where available (active promos, claims), else frame values. Create Promo shortcut. |
| Catalog – products | `market_tab_2_catalog` | CRUD on `products`. **Add Item form: NO FRAME** (name, price ₱, category, description). |
| Catalog – promotions | `market_tab_2_promotions_catalog` | List of `promos` with redeemed/limit, status Active/Scheduled/Expired. "Scan QR" → Scan screen. **Promo form: NO FRAME** (title, type bogo/percent/amount_off, value label, description, starts/ends, redeem limit). |
| Scan | **NO FRAME** | `mobile_scanner` camera + manual code entry fallback. Result card: valid → "Redeem" ; invalid/used/expired → clear error. |
| Analytics | `market_tab_3_analytics` | Funnel from `geofence_events` counts; if empty/error → default numbers (04). |
| Account | `market_tab_4_account` | Business profile, doc status list, preferences, Logout. |

## Category / interest slugs (shared by profiles.interests and businesses.category)
`food` Food & Restaurants · `cafe` Cafés · `salon` Salons & Barbershops · `retail` Retail & Shopping ·
`grocery` Groceries & Convenience · `wellness` Health & Wellness · `services` Services ·
`travel` Travel & Accommodation.
Merchant registration categories map: Food & Beverage→`food` (or `cafe` if chosen), Retail→`retail`,
Services→`services`, Accommodation→`travel`, Handicrafts & Local Goods→`retail`.

## Routing rules
- On app start: Supabase session? → load `profiles.role` → shopper → Dashboard; merchant → if business
  verified → Dashboard, else Waiting.
- Logout returns to Role selection and stops the geofence service.
