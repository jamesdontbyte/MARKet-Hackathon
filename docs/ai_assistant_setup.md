# AI Assistant Setup & Deployment Guide (Phase 11)

This guide provides the step-by-step instructions for deploying and verifying the Google Gemini AI Assistant backend in Supabase for MARKet.

---

## 1. Prerequisites & Database Setup

> [!IMPORTANT]
> **Do not run migrations automatically.** Review SQL files and apply them manually in the Supabase SQL Editor.

1. **Phase 10 Media Patch Requirement:**
   - If `db/schema_patch_media.sql` has not been applied yet to your Supabase project, execute it in the Supabase SQL Editor.
   - It ensures the `image_url` column exists on `promos` and that the `business-media` storage bucket policies are configured.

2. **Phase 11 AI Rate Limiting Schema Patch:**
   - Open the Supabase Dashboard > **SQL Editor**.
   - Copy the contents of [`db/schema_patch_ai.sql`](file:///c:/Users/James/Hackthon/MARKet-Final/db/schema_patch_ai.sql).
   - Execute the script.
   - This creates the `ai_usage` table with Row Level Security (RLS) restricting reads and inserts to `auth.uid()`, enforcing the 20 requests/user/hour rate limit using the caller's JWT.

---

## 2. Obtain Gemini API Key & Configure Supabase Secrets

1. Navigate to [Google AI Studio](https://aistudio.google.com/) and create a free-tier API key (no billing required).
2. Store the secret in your Supabase project using the Supabase CLI:
   ```bash
   supabase secrets set GEMINI_API_KEY="<YOUR_GEMINI_API_KEY_HERE>"
   ```
   Alternatively, in the Supabase Dashboard, go to **Project Settings > Edge Functions > Secrets** and add `GEMINI_API_KEY`.

> [!CAUTION]
> **Security Rule:** Never place the Gemini API key in client code, `lib/core/env.dart`, tests, documentation, or Git commits.

---

## 3. Deploy the Edge Function

1. From the repository root, deploy the `chat` function with JWT verification enforced:
   ```bash
   supabase functions deploy chat --no-verify-jwt=false
   ```
   *(Ensure "Verify JWT" remains turned ON in the Supabase Dashboard).*

2. Verify that the function environment variables include:
   - `SUPABASE_URL` (injected automatically by Supabase)
   - `SUPABASE_ANON_KEY` (injected automatically by Supabase)
   - `GEMINI_API_KEY` (configured in Step 2)

---

## 4. Model Compatibility Finding

- **Configured Model Identifier:** `gemini-3.8-flash` is set at the top of `supabase/functions/chat/index.ts`.
- **API Support Note:** As of current Google Generative AI REST API releases, official production flash models typically include `gemini-1.5-flash`, `gemini-2.0-flash`, or `gemini-2.5-flash`.
- If Google's API returns a 404 or unsupported model error for `gemini-3.8-flash`, change the constant `GEMINI_MODEL` in `supabase/functions/chat/index.ts` to `gemini-1.5-flash` or `gemini-2.0-flash` and redeploy.

---

## 5. Verification & Test Cases

### Test Case 1: Anonymous / Unauthenticated Rejection
- Send a `POST` request to `https://<project-ref>.supabase.co/functions/v1/chat` without an `Authorization` header.
- **Expected:** Status `401 Unauthorized`.

### Test Case 2: Shopper Mode — Proximity & Alerts
- Log in as a Shopper.
- Tap the **Assistant** floating button on the Shopper Dashboard.
- **Query:** "Why am I not getting alerts?"
- **Expected:** Explains 6 prerequisites (Allow all the time background location, notifications enabled, battery optimization Unrestricted, GPS toggle on, interests configured, verified store within ~200m).
- **Query:** "Promos near me"
- **Expected:** Renders promotions sorted/filtered using device-calculated distances. May propose `open_promo` or `propose_save_to_stash`.

### Test Case 3: Merchant Mode — Action Proposal
- Log in as an MSME Merchant with a verified store.
- Tap **Assistant** floating button or go to **Account > AI Assistant & Help**.
- **Query:** "Create a promo for me"
- **Expected:** Drafts promo copy wrapped in `:::draft ... :::` (with Copy button) and generates an action proposal card for `propose_promo`.
- Tap **Review & Create Promo**: Opens the existing New Promo modal prefilled. The merchant selects or attaches a photo (or chooses "Use My Shop Photo") and saves.

### Test Case 4: Content Safety & Out-of-Scope Refusal
- **Query:** "What's the weather in Manila today?" or "Tell me a story about aliens."
- **Expected:** Friendly refusal or redirection back to hyperlocal store discovery and MSME promotion management in San Jose de Buenavista.

### Test Case 5: Rate Limiting
- Submit 21 queries within 1 hour as the same user.
- **Expected:** 21st query returns status 429 with message: "Rate limit reached. You can make up to 20 requests per hour. Please try again in a little while."
