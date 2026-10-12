# MARKet — Hackathon Live Demo Script (1-Page)

**Project:** MARKet (Hyperlocal MSME Promo Discovery & Redemptions for San Jose de Buenavista, Antique)  
**Demo Devices:** Android Phone (Samsung A36 / Android 14+)  
**Accounts:**
- **Shopper:** `demo@gmail.com` (One-tap: "Demo Shopper")
- **Merchant:** `james@gmail.com` (One-tap: "Demo Merchant (Kape Tahanan)")

---

## 1. Demo Flow & Step-by-Step Script

| Step | Action | What Happens On Screen | What to Say (Pitch Points) |
|---|---|---|---|
| **1. Splash & Role Selection** | Launch app. | Branded splash screen with dual-tone MARKet logo smoothly routes to Login screen. | *"Traditional social media ads are expensive and ignored by locals walking down the street. MARKet bridges physical foot traffic and Antique's MSMEs using battery-efficient, hyperlocal geofencing."* |
| **2. Shopper Login & Permissions** | Tap **"Demo Shopper"** one-tap button. | Immediate login without typing passwords. Dashboard loads verified Antique MSMEs. | *"With our one-tap access, shoppers instantly view nearby verified businesses like Kape Tahanan. Notice how verified DTI/LGU MSMEs are highlighted to protect consumers."* |
| **3. Trigger Hyperlocal Promo Alert** | **Method A (Simulation):** Long-press the **MARK** logo in the header → Tap **"Simulate entering zone"**.<br>**Method B (Real/Mock GPS):** Set Fake GPS inside San Jose zone (`10.7674886, 121.9428977`, radius 4400m). | Local heads-up notification fires immediately: **"Promos near you in San Jose"** with deal: *"Buy 1 Take 1 Muscovado Cold Brew at Kape Tahanan"*. | *"MARKet runs its own zero-cost geofencing engine via an Android foreground service. When a shopper enters San Jose de Buenavista, our geofence triggers a high-priority local notification — even when the app is minimized or the screen is locked."* |
| **4. Notification Tap & Promo Discovery** | Tap the notification banner from the system tray or lockscreen. | Directly deep-links to **Promo Detail Screen** displaying terms, valid dates, and Kape Tahanan details. | *"Deep linking brings the shopper straight to the merchant's promotion terms. No search needed, zero friction."* |
| **5. Claim Voucher & QR Code** | Tap **"Get Voucher"**. | Generates a unique atomic **QR Voucher** and formatted 8-character manual code (e.g. `KT-7X9B21`). | *"Claiming generates an offline-ready single-use QR voucher with an 8-character fallback code backed by atomic Postgres database constraints."* |
| **6. Switch to Merchant Role** | Navigate to Account tab → Tap **"Log Out"** → Tap **"Demo Merchant (Kape Tahanan)"**. | Logs into Kape Tahanan's Merchant Dashboard with Performance Overview and active promos. | *"Now, let's step into the shoes of Carlos, owner of Kape Tahanan on San Jose's main street."* |
| **7. Merchant QR Scanner & Atomic Redemption** | Go to Catalog → tap **"Promotions"** toggle → tap **"Scan QR"** (or scan camera icon). | Opens camera QR reader with targeting overlay. Scan the shopper's voucher (or enter 8-character code). | *"When the customer arrives at the counter, the cashier scans the QR code. The app calls our secure RPC redeem_voucher function — preventing double redemption."* |
| **8. Redemption Success Card** | View scan result. | Instant green **"Voucher Redeemed!"** card with timestamp and discount summary. | *"The voucher is instantly burned in Postgres. If the cashier attempts to scan the same voucher again, the system immediately rejects it as 'Already Redeemed'."* |
| **9. MSME Conversion Analytics** | Tap **"Analytics"** on the bottom navigation (Tab 2). | Interactive 7-Day Conversion Funnel with Animated Radar Range visualizer and footfall insights. | *"Finally, Carlos gets actionable foot traffic analytics: from geofence zone entries to notifications opened, store views, claims, and counter redemptions. Small merchants now have enterprise-grade funnel data compliant with Philippine Data Privacy Act (RA 10173)."* |

---

## 2. If Something Goes Wrong (Contingency Playbook)

| Issue | Cause | Immediate Fallback Action |
|---|---|---|
| **Notification doesn't appear** | Android OEM battery optimization or GPS sleep mode. | **Use the built-in demo shortcut:** Long-press the **"MARK"** logo in the top app bar on the Shopper Dashboard → tap **"Simulate entering zone"**. It triggers the identical notification payload and handler. |
| **Camera cannot scan QR code** | Glare, poor lighting, or camera hardware permission denied. | Tap **"Enter 8-Character Code Manually"** on the scanner screen. Type the 8-character code printed directly beneath the QR code on the voucher (case-insensitive) and tap **Redeem Code**. |
| **OpenStreetMap tiles fail to render** | Cellular network delay or blocked tile server. | The Roam screen automatically detects tile load errors and flips to the **List View**. You can also manually tap the **"List"** toggle pill at the top-right to view all verified San Jose businesses with full directions and storefront details. |
| **No cellular internet connection** | Venue signal drop. | The app handles empty states gracefully without crashing. Pre-cached mock data and benchmark indicators marked **"Sample data"** automatically activate for the merchant analytics funnel, ensuring zero blank screens. |
| **Need to inspect raw GPS diagnostics** | Judges ask for proof of background GPS foreground service. | Tap the Shopper or Merchant Account tab → tap **"Open Geofence Spike Screen"** (visible when `demoMode = true`). Shows live GPS latitude/longitude, accuracy, distance to zone center, and real-time logs. |
