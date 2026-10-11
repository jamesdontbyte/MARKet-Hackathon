---
name: Merchant Pulse
colors:
  surface: '#f8f9ff'
  surface-dim: '#cbdbf5'
  surface-bright: '#f8f9ff'
  surface-container-lowest: '#ffffff'
  surface-container-low: '#eff4ff'
  surface-container: '#e5eeff'
  surface-container-high: '#dce9ff'
  surface-container-highest: '#d3e4fe'
  on-surface: '#0b1c30'
  on-surface-variant: '#3e484f'
  inverse-surface: '#213145'
  inverse-on-surface: '#eaf1ff'
  outline: '#6e7980'
  outline-variant: '#bdc8d1'
  surface-tint: '#006689'
  primary: '#006689'
  on-primary: '#ffffff'
  primary-container: '#3ec4ff'
  on-primary-container: '#004e6b'
  inverse-primary: '#7ad0ff'
  secondary: '#565e74'
  on-secondary: '#ffffff'
  secondary-container: '#dae2fd'
  on-secondary-container: '#5c647a'
  tertiary: '#006398'
  on-tertiary: '#ffffff'
  tertiary-container: '#6fbfff'
  on-tertiary-container: '#004d76'
  error: '#ba1a1a'
  on-error: '#ffffff'
  error-container: '#ffdad6'
  on-error-container: '#93000a'
  primary-fixed: '#c3e8ff'
  primary-fixed-dim: '#7ad0ff'
  on-primary-fixed: '#001e2c'
  on-primary-fixed-variant: '#004c68'
  secondary-fixed: '#dae2fd'
  secondary-fixed-dim: '#bec6e0'
  on-secondary-fixed: '#131b2e'
  on-secondary-fixed-variant: '#3f465c'
  tertiary-fixed: '#cce5ff'
  tertiary-fixed-dim: '#93ccff'
  on-tertiary-fixed: '#001d31'
  on-tertiary-fixed-variant: '#004b73'
  background: '#f8f9ff'
  on-background: '#0b1c30'
  surface-variant: '#d3e4fe'
typography:
  display-lg:
    fontFamily: Plus Jakarta Sans
    fontSize: 32px
    fontWeight: '800'
    lineHeight: 40px
  display-lg-mobile:
    fontFamily: Plus Jakarta Sans
    fontSize: 26px
    fontWeight: '800'
    lineHeight: 34px
  headline-lg:
    fontFamily: Plus Jakarta Sans
    fontSize: 24px
    fontWeight: '700'
    lineHeight: 32px
  headline-md:
    fontFamily: Plus Jakarta Sans
    fontSize: 20px
    fontWeight: '700'
    lineHeight: 28px
  headline-sm:
    fontFamily: Plus Jakarta Sans
    fontSize: 18px
    fontWeight: '600'
    lineHeight: 24px
  body-lg:
    fontFamily: Plus Jakarta Sans
    fontSize: 16px
    fontWeight: '400'
    lineHeight: 24px
  body-md:
    fontFamily: Plus Jakarta Sans
    fontSize: 14px
    fontWeight: '400'
    lineHeight: 20px
  body-sm:
    fontFamily: Plus Jakarta Sans
    fontSize: 13px
    fontWeight: '400'
    lineHeight: 18px
  label-lg:
    fontFamily: Plus Jakarta Sans
    fontSize: 14px
    fontWeight: '600'
    lineHeight: 20px
  label-md:
    fontFamily: Plus Jakarta Sans
    fontSize: 12px
    fontWeight: '600'
    lineHeight: 16px
  label-sm:
    fontFamily: Plus Jakarta Sans
    fontSize: 11px
    fontWeight: '700'
    lineHeight: 14px
    letterSpacing: 0.02em
rounded:
  sm: 0.25rem
  DEFAULT: 0.5rem
  md: 0.75rem
  lg: 1rem
  xl: 1.5rem
  full: 9999px
spacing:
  gutter: 1rem
  gutter-mobile: 0.75rem
  margin: 1.5rem
  margin-mobile: 1rem
  space-xs: 0.25rem
  space-sm: 0.5rem
  space-md: 1rem
  space-lg: 1.5rem
  space-xl: 2rem
---

## Brand & Style

This design system is tailored for MSME (Micro, Small, and Medium Enterprises) merchants seeking an intuitive, welcoming, and high-efficiency interface to manage their storefront and highlight business offerings.

### Personality & Emotional Response
The aesthetic merges professional operational clarity with approachable warmth. It avoids the intimidating complexity of enterprise SaaS while providing more polish and structure than casual consumer apps. The interface instills confidence, optimism, and composure, empowering business owners through high-contrast legibility, calm whitespaces, and friendly tactile accents.

### Design Style: Soft Clean Modern
The visual direction combines crisp minimalism with tactile softness:
- **Base Surfaces:** Pure, airy light backdrops accented by gentle card separations.
- **Accents:** High-energy sky cyan highlights key interactive triggers, status pulses, and active tags without overwhelming visual hierarchy.
- **Containers:** Spacious cards with generous corner radii, faint containment lines, and airy diffused drop shadows that eliminate visual friction.
- **Atmosphere:** Clean, open, and lightweight. Content and shop photography (exterior imagery, featured catalog items, promo banners) remain the central heroes.

## Colors

The palette is engineered around high functional clarity, soft surface differentiation, and targeted focal points.

### Role Tokens & Hierarchy
- **Canvas Base:** `#FFFFFF` (crisp canvas) paired with `#F8FAFC` for background sectioning and offset rails.
- **Card Surfaces:** `#FFFFFF` with structural borders set to `#F1F5F9` (primary dividers) and `#E2E8F0` (interactive outlines and fields).
- **Primary Accent (`#3EC4FF`):** Reserved for primary CTAs, active segmented toggles, key badges, progress indicators, and actionable highlights. Hover/focus states shift down to deep sky blue (`#0284C7`).
- **Primary Text & Headings (`#0F172A`, `#1E293B`):** Deep charcoal slate engineered for maximum legibility on bright backgrounds, exceeding WCAG AAA standards.
- **Secondary & Meta Text (`#64748B`):** Muted slate for form captions, timestamps, metrics labels, and auxiliary descriptions.
- **Soft Interactive Tint (`#E0F2FE` / `#F0F9FF`):** Ultra-light cyan washes applied to active icon badges, highlighted table rows, and selected filter chips.
- **Semantic Feedback:**
  - Success: `#10B981` (active promotions, open shop status).
  - Warning: `#F59E0B` (low stock, expiring voucher).
  - Danger: `#EF4444` (critical alerts, discontinued items).

## Typography

This system standardizes on **Plus Jakarta Sans** across all roles to unify clean geometric legibility with warm, rounded humanist nuances.

### Application Rules
- **Display & Section Headers:** Set in bold and extra-bold weights (`700`, `800`) to anchor mobile viewports and delineate content blocks (e.g., "Today's Revenue", "Active Promos", "Storefront Profile").
- **Body Text:** Kept light and clear using weight `400` with comfortable line-heights (`1.4` to `1.5`) ensuring fast, fatigue-free scanning during daily store operation.
- **Labels & Tags:** Use `600` and `700` weights for quick metadata intake, category chips, and actionable labels.
- **Numbers & Currencies:** Pair `Plus Jakarta Sans` numbers with tabular spacing (`font-variant-numeric: tabular-nums`) within data tables, stock counts, and financial stats to ensure vertical visual alignment.

## Layout & Spacing

The layout is built mobile-first, targeting frictionless thumb-zone navigation and clear modular dashboard cards.

### Grid & Layout Rules
- **Mobile Grid (viewport < 768px):** 4-column fluid layout with an outer canvas padding (`margin-mobile`) of `1rem` (16px) and an inner element gutter of `0.75rem` (12px). Full-width cards stack vertically with internal padding set to `1.25rem` (20px).
- **Tablet / Responsive Expand (768px - 1024px):** 8-column layout with `1.5rem` (24px) side margins. Dashboard metrics reflow into a 2x2 grid; promotional banners and best-seller lists display side-by-side.
- **Rhythm & Padding:** Base spacing adheres to an 8pt increment model. Component gaps default to `space-md` (16px), while tight badge and icon associations use `space-xs` (4px) or `space-sm` (8px). Large structural sections (e.g., switching between "Shopfront Setup" and "Sales Metrics") use `space-xl` (32px).
- **Edge bleed:** Carousel rows (such as featured promo cards and best-selling item cards) bleed to viewport edges on mobile using `-margin-mobile` negative margins with internal padding to maintain fluid horizontal scrolling.

## Elevation & Depth

This system avoids aggressive multi-color gradients and harsh drop shadows. Instead, it relies on soft ambient light, faint boundaries, and subtle tonal separation.

### Surface Elevation Hierarchy
- **Level 0 (App Canvas):** Plain `#FFFFFF` or flat tinted background `#F8FAFC`.
- **Level 1 (Card & Section Containers):** Pure white `#FFFFFF` surface accompanied by a subtle 1px border (`#F1F5F9`) and a soft diffused shadow:
  - `box-shadow: 0 4px 20px -2px rgba(15, 23, 42, 0.04), 0 2px 6px -1px rgba(15, 23, 42, 0.02)`
- **Level 2 (Interactive Floating Elements, Dropdowns, Sheets):** Lifted surfaces, floating navigation bars, and active dialog sheets:
  - `box-shadow: 0 12px 32px -4px rgba(15, 23, 42, 0.08), 0 4px 12px -2px rgba(15, 23, 42, 0.03)`
  - Border: 1px solid `#E2E8F0`
- **Active State / Press Feedback:** Elements sink toward the surface (`scale(0.98)` or shadow elevation drop to 2px offset) providing tactile, responsive feedback.

## Shapes

The shape system leverages welcoming, organic rounded corners to convey hospitality, friendliness, and accessibility.

### Application Specs
- **Default Elements:** 8px (`0.5rem`) for form inputs, chips, badge tags, and buttons.
- **Card Containers (`rounded-2xl`):** 16px to 20px radius on all main content cards (e.g., Best Sellers card, Store Hours block, Promo summary).
- **Feature Banners & Modal Sheets (`rounded-3xl`):** 24px radius on storefront hero cover displays, promotional callout banners, and bottom drawer sheets.
- **Fully Pill-Shaped:** Badges, active live indicators, pill toggles, and floating quick-action buttons maintain `border-radius: 9999px`.

## Components

### Buttons
- **Primary Action:** Solid `#3EC4FF` background, `#0F172A` high-contrast typography, bold weight (`600`), 12px vertical padding, 20px horizontal padding, radius `0.75rem` (12px). Hover state transitions to `#38BDF8`.
- **Secondary / Ghost Action:** Border `1px solid #E2E8F0`, background `#FFFFFF`, text `#0F172A`. Active state applies light cyan wash `#F0F9FF`.
- **Destructive Action:** Soft tinted background `#FEE2E2` with `#DC2626` text.

### Cards (Dashboard Containers)
- Surface `#FFFFFF`, border `1px solid #F1F5F9`, rounded corners `16px` to `20px`.
- Padding defaults to `16px` or `20px`.
- Cards grouping data (e.g., "Active Promos", "Business Story") feature a distinct header row with title in `headline-sm`, optional action links ("Manage", "See All") in `#0284C7`.

### Chips & Filter Tags
- **Default State:** Background `#F8FAFC`, border `1px solid #E2E8F0`, text `#64748B`, font-size `12px`, padding `6px 12px`, pill-shaped (`9999px`).
- **Active / Selected State:** Background `#E0F2FE`, border `1px solid #3EC4FF`, text `#0284C7`, font weight `600`.

### Form Inputs & Selectors
- Background `#FFFFFF`, border `1px solid #CBD5E1`, text `#0F172A`, placeholder `#94A3B8`.
- Focus state activates a distinct 2px outer ring in `#3EC4FF` with border `#3EC4FF`.
- Corner radius fixed to `10px` with generous touch targets (minimum `48px` height).

### Checkboxes & Radios
- Radio circles and checkbox squares with `6px` radius.
- Unchecked: `1.5px solid #CBD5E1` with `#FFFFFF` center.
- Checked: `#3EC4FF` background with clean `#0F172A` or `#FFFFFF` checkmark/indicator.

### Storefront Exterior Showcase Card
- Aspect ratio `16:9` or `2:1` rounded image frame (`16px` radius) with subtle inner gradient overlay at bottom edge to support store name and open/closed operational pill badge.

### Promo & Voucher Badges
- Dashed or solid `#BAE6FD` boundary with a `#F0F9FF` background. Accent text in `#0369A1` accompanied by a bright cyan tag marker for discount codes and active campaigns.