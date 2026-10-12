# Specification 05: In-App AI Assistant (Google Gemini)

Hyperlocal MSME promo discovery and management assistant for San Jose de Buenavista, Antique.
Supports two distinct roles: Shopper and MSME Merchant.
Operates in an AGENTIC mode where the model proposes actions, but the application only executes them after explicit user confirmation.

---

## 1. Overview & Architecture

### Backend: Supabase Edge Function (`supabase/functions/chat/index.ts`)
- **Runtime:** Deno on Supabase Edge Functions.
- **Model:** `gemini-3.8-flash` via Google Generative AI REST API with function declarations.
- **Authentication:** Requires valid, non-anonymous JWT from caller's `Authorization: Bearer <token>` header. Never trust client-supplied roles; queries the caller's role directly from `public.profiles`.
- **Security:** Secret `GEMINI_API_KEY` accessed exclusively in the Edge Function via `Deno.env.get('GEMINI_API_KEY')` and passed in `x-goog-api-key` header. Never present in Flutter app, env.dart, Git, or logs.
- **Privacy:** Coordinates, user phone numbers, emails, and merchant owner identities are NEVER sent to Gemini.
- **Rate Limiting:** Maximum 20 requests per user per hour tracked in `public.ai_usage` with Row Level Security.
- **Context Integrity:** All database promo/product/review texts are treated as untrusted data. Instructions within database content are disregarded.
- **Output:** `{ reply: string, action?: { name: string, args: Record<string, any> } }` or `{ error: string, code: string }`.

---

## 2. Role Modes & Capabilities

### Shopper Mode
- **Context Provided:**
  - Up to 15 active, verified, currently valid promos (`id`, `title`, `value_label`, `promo_type`, `business_name`, `category`, `ends_at`, and device-computed `distance_m` if available).
  - Shopper's registered interest categories (`profiles.interests`).
  - IDs of promotions already saved in the shopper's `stash`.
- **Core Skills:**
  1. Find and compare promotions by interest, budget, or category.
  2. Explain Stash and how redemption works:
     - Merchant displays an on-counter QR code and 8-character code refreshing ~60s.
     - Shopper opens Stash > Redeem at store, then scans the QR, uploads a QR image, or enters the 8-character code.
  3. Troubleshoot missing hyperlocal notifications:
     - "Allow all the time" location permission.
     - Notifications enabled (`POST_NOTIFICATIONS`).
     - Battery optimization set to Unrestricted.
     - Device GPS/Location toggle turned on.
     - Shopper interests selected.
     - Verified merchant establishment with an active promotion within ~200 meters.
- **Proposal Tools:**
  - `open_promo(promo_id: string)`
  - `open_store(business_id: string)`
  - `propose_save_to_stash(promo_id: string)`

### Merchant Mode
- **Context Provided:**
  - Authenticated merchant's business profile (name, category, subtitle, bio, address, hours, verified status).
  - Merchant catalog products (names, prices, categories, descriptions, availability).
  - Merchant promotions (IDs, titles, types, value labels, start/end dates, redeem limits, redeemed counts, active state).
  - 7-day funnel analytics from `geofence_events` (ping_sent, opened, viewed, claimed, redeemed).
- **Core Skills:**
  1. Draft compelling promotion titles, terms, and descriptions.
  2. Recommend discount structures (`bogo`, `percent`, `amount_off`) and valid durations (≤ 90 days).
  3. Explain store analytics in plain language, identify the weakest funnel step, and provide one concrete suggestion.
  4. Explain store verification requirements and how the counter Store QR screen works.
  5. Draft store announcements and marketing blurbs.
  6. Explain that image generation is not supported, guiding the user to upload a photo or use their existing shop photo.
- **Proposal Tools:**
  - `propose_promo(title: string, description: string, promo_type: string, value_label: string, starts_at: string, ends_at: string, redeem_limit: number)`
  - `propose_product(name: string, price: number, category: string, description: string)`
  - `pause_promo(promo_id: string)`
- **Validation Rules (Server-side):**
  - Promotion title: max 60 characters.
  - Promotion description: max 200 characters.
  - `promo_type`: must be one of `'bogo'`, `'percent'`, `'amount_off'`.
  - `ends_at` strictly after `starts_at` and within 90 days of start.
  - `redeem_limit`: 1 to 1,000.
  - Product price: ≥ 0.
  - Business must be verified and owned by caller.
  - All target IDs must belong to caller's business.
  - On validation error, return friendly feedback to user instead of an action.

---

## 3. UI & UX Specifications

- **Screen:** `AssistantScreen` (`lib/screens/shared/assistant_screen.dart`).
- **Header:** `AppHeader(subtitle: 'Assistant', showBack: true)`.
- **Design Tokens:** Strict adherence to `MarketColors`, `MarketSpacing`, `MarketRadii`, `MarketElevation`, and `Plus Jakarta Sans`.
- **Empty State:**
  - AI Assistant badge + disclaimer ("AI Assistant • Responses may be inaccurate. Verify important details.").
  - 3 Role Suggestion Chips:
    - Shopper: "Promos near me", "How do I redeem a voucher?", "Why am I not getting alerts?"
    - Merchant: "Create a promo for me", "Summarize my week", "How does the Show QR work?"
- **Draft Extraction:**
  - Model outputs drafts wrapped in `:::draft ... :::`.
  - Parsed into distinctive draft card widgets with a 1-tap "Copy" button.
- **Action Confirmation Cards:**
  - `propose_promo`: Pre-fills the existing New Promo modal in `MerchantCatalogScreen`. Requires merchant to attach a photo or pick "Use my shop photo" before saving.
  - `propose_product`: Pre-fills the existing Add Item modal in `MerchantCatalogScreen`.
  - `pause_promo`: Displays confirmation card with "Confirm" and "Cancel" buttons. Calls `DataService.updatePromo` only on confirmation.
  - `propose_save_to_stash`: Displays confirmation card with "Confirm" and "Cancel" buttons. Calls `DataService.saveToStash` only on confirmation.
  - `open_promo`: Pushes `PromoDetailScreen(promoId: ...)`.
  - `open_store`: Pushes `StorefrontScreen(business: ...)`.
- **Entry Points:**
  - Floating action button on Shopper Dashboard (`lib/screens/shopper/dashboard_screen.dart`).
  - Floating action button on Merchant Dashboard (`lib/screens/merchant/dashboard_screen.dart`).
  - Help tile on Merchant Account Screen (`lib/screens/merchant/account_screen.dart`).
