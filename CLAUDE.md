# Ecomflex — project handover

This file is read automatically by Claude Code at the start of every session. It describes everything built so far, why it was built that way, what is deployed, what is not, and the mistakes already made so they are not repeated. Read all of it before changing anything.

**This repository is public.** Never add passwords, secret keys, `service_role` keys, Stripe secret keys (`sk_…`, `whsec_…`), bank account numbers, or customer data to any file here.

Last updated: 24 September 2026.

---

## 1. The business

**Ecomflex Ltd** (Company No. 15810627) is a UK third-party logistics / fulfilment company.

- Warehouse: Aylesford Self Storage, Unit 1, The Coachworks, Old Mill Lane, Aylesford, ME20 7DT. Moving to a considerably larger warehouse soon.
- Staff: about 3 people, 2 of them admins (Mert and Erdal). Family and close friends. Small team, so simplicity beats process.
- Around 50 client stores, ~100–300 parcels a day. Only 1–3 clients do 40+ parcels a day; most send 1–2.
- Clients are **Turkish-owned businesses, usually based in the USA**. They ship stock to Ecomflex, and when they get a UK or European order, Ecomflex packs and dispatches it.
- Five service lines: **dropshipping, FBA, FBM, parcel forwarding, returns handling**.
- Carriers: Royal Mail (mainly Tracked 48) and DPD.
- Main competitor used as the design reference for the customer panel: a Turkish-run UK fulfilment company with a mature panel (dashboard, products, recipients, inventory, services, goods in, shipments, UK labels, marketplaces, balance, payment declarations, invoices, price list, support tickets). Copy the *layout ideas*, never their name or branding.

### Language rules

- **Customer-facing screens are in Turkish** (`panel.html`, `panel2.html`, `signup.html`).
- **Admin and warehouse screens are in English** (`admin.html`, `scanner.html`, `labels.html`, `index.html`).
- Carrier, legal and customer email correspondence is written in **British English**.
- The owner (Mert) communicates casually and in mixed English/Turkish. He is not a developer.

### How to work with Mert

- **Always give instructions as numbered steps in plain text.** He dislikes interactive step cards; plain numbered lists only.
- **Give deploy steps a few at a time** and wait for him to report back ("tell me what you see"). He asks "tell me step by step" when a list is too long.
- He deploys by hand through the GitHub web interface, so every change must end with explicit upload steps: which files, and in what order.
- **Put the files he must upload into one folder in his Downloads** (e.g. `Downloads\ecomflex-phase9`) so he can select them all. Clicking a file card in the Claude app only previews it; copying into Downloads is what works.
- Addresses must never end with a full stop in instructions — he once opened `signup.html.` and got a 404. Put URLs on their own line.
- He asks "what was the url" often. The answers are in section 3.
- Ask before building large features. When a message is phrased as a question ("how would this be done"), explain; build only once he says to. When he explicitly says "take your time, make it perfect", he wants the whole thing built.
- Be honest when something breaks and say what caused it. He responds well to plain explanations.

---

## 2. Architecture

- **Static hosting on GitHub Pages.** No server, no build step, no framework, no bundler. Every page is a single self-contained `.html` file with inline CSS and vanilla JavaScript (ES5 style, `var`, `function`, promises with `.then`; no arrow functions, no `let`/`const`).
- **Supabase** provides the database (Postgres), authentication, file storage, Edge Functions (Stripe only) and all business rules. Permission checks live **in the database** (row-level security and `security definer` functions), never only in the page.
- **Installable PWA**: `manifest.webmanifest` plus a service worker `sw.js`, so staff get an "Ecomflex" icon on their phone home screen.
- Libraries are loaded from CDNs at runtime with fallback lists, only when needed:
  - Supabase JS v2 UMD: jsdelivr, then unpkg. (`panel2.html` skips loading if `window.supabase` already exists — used by the test harness.)
  - pdf.js **3.11.174**: cdnjs, then unpkg, then jsdelivr.
  - ZXing library 0.21.3 (barcode fallback): cdnjs, then unpkg, then jsdelivr.
  - SheetJS `xlsx` 0.18.5 (Excel downloads/uploads in the panels): cdnjs, unpkg, jsdelivr.
  - Chart.js 4.4.1 (dashboard charts in `panel2.html`): cdnjs, jsdelivr, unpkg.
  - Stripe.js from `js.stripe.com/v3` (must come from Stripe; only when a card payment starts).
  - Inter font from Google Fonts (`panel2.html`), system font fallback.

### Why this shape

Mert wanted everything free, on his phone, and editable without a developer. Static files on GitHub Pages cost nothing and deploy by drag-and-drop. Supabase's free tier covers the database. **Supabase Pro (~$25/month) has been recommended** now that the database holds money records, for daily backups and point-in-time recovery; not yet purchased.

---

## 3. URLs, accounts and configuration

| What | Where |
|---|---|
| Repository | `github.com/kolatanya/parcel-scanner` |
| Ecomflex app (staff hub) | `https://kolatanya.github.io/parcel-scanner/` |
| Customer panel (current) | `https://kolatanya.github.io/parcel-scanner/panel.html` |
| **New customer panel (being tested)** | `https://kolatanya.github.io/parcel-scanner/panel2.html` |
| Customer signup | `https://kolatanya.github.io/parcel-scanner/signup.html` |
| Admin tool | `https://kolatanya.github.io/parcel-scanner/admin.html` |
| Supabase project ref | `padskodcofmmrwzuszym` (region: London) |
| Supabase URL | `https://padskodcofmmrwzuszym.supabase.co` |
| Stripe webhook address (when set up) | `https://padskodcofmmrwzuszym.supabase.co/functions/v1/stripe-webhook` |
| Company website | `ecomflex.co.uk` (run by someone else; its PANEL button is meant to link to the customer panel) |
| **Custom domain (being connected)** | `https://panel.ecomflex.co.uk/` (see "Custom domain" below). Once GitHub Pages has it, every `kolatanya.github.io/parcel-scanner/…` address redirects there by itself. |

- `ecomflex-config.js` holds `SUPABASE_URL`, `SUPABASE_ANON_KEY` and `STRIPE_PUBLISHABLE_KEY`. All three are public by design. The Stripe key is empty until Stripe is set up; while empty, the card top-up box stays hidden. **Never** put the `service_role` key, any `sb_secret_…` key, or Stripe's `sk_…`/`whsec_…` in this repo — those go in Supabase → Edge Functions → Secrets.
- Admin login is `info@ecomflex.co.uk`. The password is known to the owner and is **not** recorded here.
- Admins are listed in the `public.admins` table. Adding a staff member needs two steps: add their email in admin → Staff, **and** create their login in Supabase → Authentication → Users.
- Supabase settings already made: **"Confirm email" is turned OFF** (Authentication → Sign In / Providers → Email), so accounts are usable immediately.

### Custom domain `panel.ecomflex.co.uk`

Order matters, or the live site breaks:
1. **DNS first.** Whoever controls the DNS for `ecomflex.co.uk` adds one record: type `CNAME`, name `panel`, value `kolatanya.github.io`. Nothing else on the domain changes (the main website and email keep working).
2. **Then GitHub:** repository → Settings → Pages → Custom domain → `panel.ecomflex.co.uk` → Save. GitHub writes a `CNAME` file into the repo itself. Wait for the DNS check to go green, then tick **Enforce HTTPS** (the certificate can take up to an hour).
3. **Then Supabase:** Authentication → URL Configuration → Site URL `https://panel.ecomflex.co.uk`; add `https://panel.ecomflex.co.uk/**` under Redirect URLs (keep the github.io one until everyone has moved).
4. Optional but recommended: GitHub → your profile Settings → Pages → **Add a verified domain** → `ecomflex.co.uk` (a TXT record), so nobody else's GitHub Pages site can claim a subdomain of it.
5. Afterwards: update the welcome message template (admin → Customers → Bank details) and the website's PANEL button to the new address. People are signed out once (sign-ins are stored per address) and staff reinstall the home-screen app from the new address.

**Never upload a `CNAME` file by hand before the DNS record exists**: GitHub would start redirecting to an address that does not answer yet, and every page would go down.

The canonical tags, `robots.txt` and `sitemap.xml` already use `https://panel.ecomflex.co.uk/`. The `create-topup` Edge Function already allows that origin.

---

## 4. Files

All files sit **flat in the repository root**. There are no folders except a stray `New folder` from an early upload mistake (an old copy of the scanner, hub and icons). It is publicly reachable and should be deleted on GitHub.

| File | Purpose |
|---|---|
| `index.html` | "Warehouse tools", the staff home page and the site root. A `TOOLS` array at the top of its script lists the cards (`icon` is one of the SVG symbols in the page). Also links customers to the panel. |
| `scanner.html` | Live camera barcode scanner for Royal Mail and DPD. |
| `labels.html` | Label reader: drop Royal Mail label PDFs, get one spreadsheet row per parcel/SKU. |
| `panel.html` | Current customer panel, Turkish. Will be replaced by `panel2.html`. |
| `panel2.html` | **New customer panel**, Turkish, modelled on the competitor's. See 8. |
| `admin.html` | Admin console, English. The main staff application (v5). |
| `404.html` | Custom "page not found" page (Turkish, short English line). GitHub Pages serves it for any missing address. |
| `robots.txt`, `sitemap.xml` | For search engines. The sitemap lists only the public pages (`panel.html`, `signup.html`). |
| `signup.html` | Public self-signup for new customers, Turkish. |
| `shared.js` | `window.EFCopy(text, label, button)` — clipboard copy with a toast, beep, vibration and button flash. Used everywhere. |
| `ecomflex-config.js` | `window.ECOMFLEX = { SUPABASE_URL, SUPABASE_ANON_KEY, STRIPE_PUBLISHABLE_KEY }`. |
| `manifest.webmanifest`, `sw.js` | PWA manifest ("Ecomflex Warehouse Tools", staff app, starts at the hub) and service worker. Customer pages must **not** link this manifest. |
| `logo.png`, `favicon.png`, `apple-touch-icon.png`, `icon-192.png`, `icon-512.png` | Branding. `logo.png` is transparent (works on white and cream). |
| `.nojekyll` | Tells GitHub Pages not to run Jekyll. **Not currently in the repo**; harmless while no file starts with `_`. |
| `_shared.js` | Old copy of `shared.js` from the underscore mistake. Unused; can be deleted. |
| `supabase-schema.sql` | Snapshot of the whole live database, taken 21 Sep 2026. See 6. |
| `supabase-phase7.sql`, `-phase8.sql`, `-phase9.sql` | Migrations since the snapshot. |
| `supabase-function-create-topup.ts`, `supabase-function-stripe-webhook.ts` | The two Supabase Edge Functions for Stripe card top-ups. Not run from GitHub; pasted into Supabase. |
| `CLAUDE.md` | This handover. |

---

## 5. Brand and design system

Two looks exist:

**Old look** (only `panel.html` and `signup.html` now): light beige.

```css
--cream:#F4EEE2; --panel:#FFFCF6; --edge:#E1D8C6; --edge2:#D3C7AF;
--ink:#33334E; --navy:#48486C; --muted:#7C7C93;
--red:#EA3D49; --blue:#45B0C8; --deep:#2E8FA8;
--ok:#2E8FA8; --warn:#B0761A; --bad:#D62F3C;
```

**New customer panel** (`panel2.html`): Mert asked for the colours of the ecomflex.co.uk website — white and light grey surfaces, the logo red for actions, navy text, the cube blue. Inter font. Pill-shaped buttons, large page headers with a small lowercase "eyebrow", filter bars, table cards with page size, search, sorting and paging, right-side detail drawers, centred forms (full-screen on phones).

```css
--bg:#F5F6F8; --surface:#FFFFFF; --line:#E7E8EE; --ink:#23233B; --navy:#48486C; --muted:#6F7189;
--red:#EA3D49; --blue:#45B0C8; --deep:#2E8FA8;
```

Rules for both:
- Status colours: blue = done, amber = needs attention, red = problem, grey = cancelled/passive. Money in green/red.
- Monospace for codes, SKUs, tracking numbers and money.
- **Phone layout must work well.** Old tools: wider layouts only inside `@media (min-width:1100px)` and `(min-width:1560px)`. `panel2.html`: sidebar becomes a slide-in menu under 980px; tables become stacked cards under 760px.
- A version badge (`v5`) shows which admin build loaded: in the user card at the bottom of the admin menu, and under the sign-in box.

**Admin console, hub, scanner, label reader** (24 Sep 2026): same colours and Inter font as `panel2.html`, but denser and more like a business console: white left menu grouped as overview / operations / customers / customer panel / insights / settings / tools, page header with a small lowercase group name, one `h1` and a one-line description, a toolbar row (segmented tabs left, actions right), list panels with expandable rows, tables with small lowercase headers, 12px corners, **dark navy (`#23233B`) for action buttons**, logo red only for brand accents, badges and the active menu item. Pills in sentence case. Scanner and label reader only had their colour variables and font switched; their layouts are unchanged.

### Page tags (every page)

- A unique `<title>`, a `<meta name="description">`, a `<meta name="robots">` and a self-referencing `<link rel="canonical" href="https://panel.ecomflex.co.uk/…">`.
- `index, follow` only on `panel.html` and `signup.html` (they also carry Open Graph tags for link previews). Everything else (admin, hub, scanner, label reader, `panel2.html`, 404) is `noindex`.
- **Exactly one `<h1>` per file.** Admin keeps one `h1` element and moves it from the sign-in card into the page header on sign-in; its text and the tab title change per section (`Orders · Ecomflex Admin`). `panel2.html` keeps its `h1` on the sign-in card; its page headings are `h2` styled the same.
- `lang="tr"` on customer pages, `lang="en-GB"` on staff pages.
- When `panel2.html` becomes `panel.html`, give it `panel.html`'s title, description, `index, follow`, canonical and Open Graph tags.

---

## 6. Database

### Migrations

The original migration files (`supabase-setup.sql` … `supabase-phase6.sql`) **were lost** — they were never uploaded to GitHub. On 21 Sep 2026 the live database was exported and rebuilt as `supabase-schema.sql`, which replaces them. **Do not run the schema file on the live database**; it is for rebuilding from an empty project and as the reference.

Run once each, in order, in Supabase → SQL Editor → **Create a new snippet** (always a fresh, empty snippet). All are safe to re-run.

1. `supabase-schema.sql` — only on an empty project.
2. `supabase-phase7.sql` — fixes: self-signup customers could not enter the panel; "New code" locked customers out; reports/stock picker/balances ignored self-signup customers; undo-dispatch did not restore stock; `balance_of` was callable by anyone. Adds `customer_directory()`, first-top-up gate on requests and inbounds. **Deployed 21 Sep 2026.**
3. `supabase-phase8.sql` — balance page totals, bank-transfer payment declarations, card payments table and functions for Stripe. **Deployed 23 Sep 2026.**
4. `supabase-phase9.sql` — everything behind `panel2.html`: product details on stock rows, saved recipients, announcements, price list, documents, invoices, support tickets, dashboard figures. **Not yet deployed** (see 10).

When Supabase warns "creates a table without enabling Row Level Security", choose **Run and enable RLS**. To see what is really live, the export query used on 21 Sep (functions, policies, triggers, tables, one CSV cell) can be rerun; ask Claude for it.

### Tables

`access_codes, activity, admins, announcement_reads, announcements, app_settings, card_payments, client_settings, clients, contacts, documents, inbound_items, inbounds, invoices, orders, payment_declarations, price_items, ref_counter, requests, signup_requests, stock, ticket_messages, tickets, wallet_entries`

- **`admins`** — RLS on with **no policies**; only reachable through `security definer` functions.
- **`signup_requests`** — the *old* approval flow. Still holds historic customers. **New self-signup customers are only in `clients`.** Anything that lists customers must use `customer_directory()` (clients + approved legacy), never `signup_requests` alone.
- **`clients`** — one row per self-signup customer: code, email, names, company, address, phone, answers from the signup form, `unit_number`, `form_sent`, notes.
- **`stock`** — per customer per SKU: `qty`, `product_name`, `location`, `low_at`, plus (phase 9) `asin`, `barcode`, `damaged_qty` (kept apart from sellable stock), `active` (passive products are hidden from order forms). Customers edit details through `save_my_product` / `import_my_products` / `set_my_product_active`; **only staff change quantities.**
- **`orders`**, **`inbounds`** + **`inbound_items`**, **`requests`** (`kind` = `return | forward | fba`; `details` = what the customer filed, `outcome` = what staff sent back; FBA `details.lines[].new_fnsku_file` and `details.box_labels[]` hold storage paths).
- **`wallet_entries`** — the money ledger (see 7).
- **`payment_declarations`** — "I sent £X by bank transfer"; staff confirm (creates a top-up for the amount actually received) or reject with a reason.
- **`card_payments`** — one row per Stripe checkout; credited once by the webhook.
- **`contacts`** — each customer's saved recipients (own rows only).
- **`announcements`** + **`announcement_reads`** — staff news; per-customer read state.
- **`price_items`** — the price list staff maintain; customers see active lines.
- **`documents`** — PDFs shared with every customer (storage bucket `documents`).
- **`invoices`** — PDFs for one customer (storage bucket `invoices`, path `<user_id>/<file>`).
- **`tickets`** + **`ticket_messages`** — support conversations; `no` is a running ticket number; status `open` (waiting for staff) / `answered` / `closed`; `customer_seen` drives the customer's "new reply" badge.
- Customers may insert `inbound_items` only with `qty_received` empty (staff fill it when counting).
- `activity`, `client_settings`, `app_settings` (`bank_details`, `welcome_template`), `ref_counter`, `access_codes`.

### Functions (main ones)

```
is_admin()                                   the admin check used everywhere
customer_directory()                          admin: every customer (clients + approved legacy)
customer_email(user)                          internal only (not callable from browsers)
request_status(email)                         'approved' for clients rows, else legacy status
email_for_code(code) / regenerate_code(user)  code login; new code also becomes the password
register_client(code, data) / gen_code()      self-signup
my_account() / is_unlocked() / my_wallet_summary() / my_dashboard() / my_trends() / my_month()
balance_of(user)                              internal only
record_topup / adjust_balance                 admin money in / corrections (reason required)
dispatch_order / undo_dispatch                charge + dispatch atomically; undo refunds and restores stock
declare_payment / cancel_declaration          customer
confirm_declaration / reject_declaration / pending_declarations   admin
open_card_payment / record_card_topup         Stripe Edge Functions only (service role)
is_customer()                                 signed-in AND a real customer; customer functions check it
save_my_product / import_my_products / set_my_product_active / set_low_at   customer product details
create_inbound(courier, tracking, boxes, expected, note, items)   customer: notice + lines in one transaction
submit_fba / add_fba_label / cancel_request   customer (add_fba_label merges one box label on the server;
                                              the job becomes 'labelled' only when every box has one)
set_fba_labels                                legacy, still used by panel.html
set_fba_boxes / close_fba_job / close_return / receive_inbound  admin
open_ticket / reply_ticket / close_ticket / mark_ticket_seen   customer (own) or admin (any)
my_announcements / mark_announcements_read    customer
today_counts()                                admin Today board (includes payments_waiting, tickets_waiting)
list_admins / add_admin / remove_admin, onboarding, set_client_field, welcome_for, month_report, all_balances, next_ref
```

### Triggers

- `orders_dispatch` — when an order first becomes `answered` and names a SKU, stock is reduced.
- `orders_check_funds`, `requests_check_funds`, `inbounds_check_funds` — block new work until the customer's first top-up. Payment declarations, card payments, tickets, products and contacts are **not** blocked (they are how a customer gets unlocked or asks for help).
- `log_orders`, `log_inbounds`, `log_requests`, `log_access`, `log_stock` — write to `activity`.

### Storage buckets (all private, opened with 1-hour signed URLs)

- `labels` — FBA label files, `<user_id>/<request id or fba-timestamp>/<name>`. Customers read/write their own folder; admins read all.
- `invoices` — `<user_id>/<file>`. Customers read their own; only admins upload/delete.
- `documents` — any signed-in user reads; only admins upload/delete.

---

## 7. Money rules — do not break these

- **All amounts are whole pence stored as `bigint`.** £4.30 is `430`.
- **`wallet_entries` is append-only.** Mistakes are corrected with an opposite entry. Balance = `sum(pence)`.
- Kinds: `topup` (positive), `charge` (negative), `refund` (positive), `adjustment` (either sign; reason required).
- **The browser cannot write to the ledger at all.** Every movement goes through a `security definer` function.
- **Charging and dispatching happen together** in `dispatch_order`; refused with `INSUFFICIENT_FUNDS` if the balance is short.
- Prices are **set by hand by staff at dispatch time**. The price list page is information for customers, not an automatic rate card.
- **Top-ups:** (a) bank transfer — customer declares it, staff confirm the amount that actually arrived; (b) admin "Record top-up"; (c) card via Stripe (built, not yet live) — only the `stripe-webhook` Edge Function credits card money, after checking Stripe's signature, and the database refuses to credit the same checkout twice. **Ecomflex absorbs the Stripe fee** (customer pays £50, gets £50). Card limits £50–£5,000 per payment.
- Admin → Customers → **"TEST: +£50"** adds pretend money for testing. **Remove it before real customers use the system.** Use it only on test accounts; entries stay in the statement forever.
- **Unresolved, and outside the software:** prepaid balances affect revenue recognition and VAT timing; unspent balances are a liability. Mert has been advised to ask his accountant.

---

## 8. What each application does

### `panel2.html` — new customer panel (Turkish)

Sign-in: 8-character access code (primary) or email + password; link to `signup.html`. A signed-in user who is not a customer sees "Hesabınız bulunamadı". Hash routing (`#/shipments` etc.), so back/forward work.

Shell: left sidebar (company block with access code, grouped menu with counts, user card with sign-out), top bar (balance chip, announcements, notifications bell, account menu), amber lock bar until the first top-up.

Pages: **Genel Bakış** (greeting, stock/damaged/active products/balance cards, quick actions, account card, announcements, warehouse address, storage status, open work, damaged stock, 12-month stock and money charts, recent activity) · **Ürünler** (add/edit, bulk upload from Excel/CSV/paste, template, active/passive) · **Alıcılar** (saved recipients, import from past shipments) · **Stok** (quantities, damaged, location, low-stock threshold, Excel) · **Gönderiler** (list by date range with filters, detail drawer with tracking, new shipment form with saved recipients and stock check, bulk shipments, Excel) · **Gelen Kargo** (announce deliveries with item lines, declared vs counted) · **Hizmet Talepleri** (returns, forwarding, FBA tabs; FBA box label upload per box) · **Bakiye** (totals, bank details, card top-up when Stripe key set, statement, Excel) · **Ödeme Bildirimleri** · **Faturalar** · **Aylık Özet** · **Fiyat Listesi** · **Belgeler** · **Depo Adresim** · **Destek Talepleri** (tickets with conversation).

Notifications are worked out in the browser from the customer's own records (dispatched orders, received deliveries, FBA boxes ready, payments confirmed/rejected, ticket replies, new invoices) with a "last seen" time in localStorage.

### `panel.html` — current customer panel (Turkish)

The older, simpler panel. Still live until `panel2.html` is approved; then `panel2.html` is renamed to `panel.html`. Has the phase 8 balance page and (23 Sep) the FBA label-file fix.

### `admin.html` — admin console (English, v5)

Sections: **Today, Orders, Inbound, Services, Stock, Customers, Support, Access requests, Content, Reports, Staff**, plus links to the label reader, scanner and customer panel. Each section has an address (`admin.html#orders`, `#customers`, `#reports`…), so refresh keeps the place and Back works. On phones the menu slides in from a button at the top left.

v5 (24 Sep 2026) was a redesign only: every element ID, database call and workflow is the same as v4. Changes beyond looks: Today groups waiting work into panels with "View all"; Orders lists customers with waiting orders first and folds dispatched orders behind "Show N dispatched orders"; the customer table's less common actions (adjust balance, copy welcome message, new access code, TEST +£50) sit under a **More** menu next to **Record top-up**; the audit log shows amounts in pounds.

- **Today**: tiles incl. bank transfers to confirm and support tickets waiting.
- **Stock**: per customer; quantity, damaged, location, threshold, ASIN, barcode, active.
- **Support**: tickets by status; open one to read the thread, reply (marks it answered) or close.
- **Customers**: Onboarding, Active customers, **Payments** (confirm/reject bank transfers), **Invoices** (upload a PDF for a customer; list, open, delete), Bank details.
- **Content**: **Announcements** (post, hide, delete), **Price list** (edit lines in pounds), **Documents** (upload PDFs for all customers).
- Orders (incl. label PDF matching), Inbound, Services (FBA box builder), Access (legacy), Reports, Staff as before.

### Others

`index.html` hub, `scanner.html` (v8, camera barcode scanner — camera OCR was abandoned, do not reintroduce), `labels.html` (Royal Mail label PDF reader; parsing rules unchanged), `signup.html` (self-signup; code shown once).

### Stripe card top-ups (built, not live)

`create-topup` Edge Function (JWT verification ON) makes a Stripe embedded Checkout Session for the signed-in customer and records it with `open_card_payment`. `stripe-webhook` (JWT verification OFF; checks the `Stripe-Signature` HMAC with a 5-minute tolerance) calls `record_card_topup` on `checkout.session.completed` when paid in GBP. Secrets: `STRIPE_SECRET_KEY`, `STRIPE_WEBHOOK_SECRET`. Mert will set Stripe up himself after a meeting with Ecomflex; test first in Stripe test mode with card 4242 4242 4242 4242, then swap to live keys.

---

## 9. Deployment procedure

1. Run any new SQL: Supabase → SQL Editor → **Create a new snippet** → paste the whole file → Run. Never paste into an old snippet.
2. Put the changed files in one folder in Downloads.
3. GitHub → repository → **Add file → Upload files** → "choose your files" → select the **files, not the folder** → Commit changes.
4. Wait about a minute, then use an incognito window or hard-refresh (Ctrl+Shift+R). Check the admin version badge.

**Bump the `CACHE` constant in `sw.js` on every deploy** (currently `ecomflex-v19`) and add any new file to its `CORE` list. Since v19 the service worker only stores successful responses, so a 404 page never becomes an offline copy.

---

## 10. Current state (24 Sep 2026)

### Deployed and working

- Hub, scanner, label reader, `signup.html`.
- Phase 7 (fixes) and phase 8 (balance page, payment declarations, TEST +£50 button, admin v3). Mert tested: self-signup + code login, declaration → admin confirm → unlock, test top-up, Excel download. Bank details are entered.
- Phase 9 (23 Sep): `supabase-phase9.sql` run; `panel2.html`, admin v4, `panel.html` FBA fix, `sw.js` v18 uploaded.

### Ready to deploy (built and tested, not uploaded)

- Admin v5 redesign, new hub, `404.html`, `robots.txt`, `sitemap.xml`, page tags and single `h1` on every page, scanner/label reader colours, `manifest.webmanifest`, `sw.js` v19, `CLAUDE.md`. No SQL.
- Tested with: 48 admin click-through checks (the 27 from v4 plus section addresses, single `h1`, tab titles, Back button, folded orders, dispatch call, More menu, TEST top-up amount, phone menu, no sideways scrolling), the 52 customer checks on `panel2.html` again, a page audit (title, description, robots, canonical, one `h1` per file, no duplicate titles), the 404 page served at both `/` and `/parcel-scanner/`, and screenshots at 1440×900 and 390×844.

### Custom domain

- Waiting on the DNS record for `panel.ecomflex.co.uk` (see 3). Then GitHub Pages and Supabase settings.

### Waiting

- Stripe setup (Mert, after meeting Ecomflex). Card top-up is hidden until then.
- `regenerate_code` writes the new code as the Supabase password (`auth.users`); confirm "New code" works on the live project.
- Swap `panel2.html` → `panel.html` once Mert approves it; update the website's PANEL button if needed.
- Remove the TEST +£50 button before real customers use the system.

### Known data to clean up

- Test rows in `signup_requests`, an early FBA request with no `ref`, test users in Supabase → Authentication → Users (a user with ledger entries cannot be deleted: `wallet_entries` blocks it by design).

---

## 11. Mistakes already made — do not repeat

1. **Jekyll hides files starting with an underscore.** Never name a published file with a leading underscore.
2. **RLS recursion on the admins table.** Always use `public.is_admin()` inside policies.
3. **Page-wide selectors.** Scope selectors to a container ID.
4. **Colliding element IDs.** Check for duplicate IDs after every change.
5. **Large slice replacements destroyed code.** Make small edits anchored on unique strings; afterwards confirm every function still exists exactly once and none were lost (compare against the previous version).
6. **Features lost during cleanup.** After structural changes, re-verify each feature renders.
7. **Service-worker caching.** Always bump the cache version; test in incognito.
8. **Parsing assumptions.** Anchor on stable structure, not on the shape of codes.
9. **Test harnesses that always pass.** Check real results; never write `|| true` into a check.
10. **Migration files kept only on a laptop.** They were lost. Every SQL file goes into the repo when it is run.
11. **Browser updates that RLS silently ignores.** The old panel attached FBA label files with `requests.update(...)`; customers have no update policy, so it changed 0 rows **without an error** and staff never saw the files. Customer writes to shared tables go through `security definer` functions, or the data travels with the insert.
12. **Two customer lists.** Self-signup customers live in `clients`, old ones in `signup_requests`. Screens and reports that read only `signup_requests` silently missed every new customer. Use `customer_directory()`.
13. **Changing only the `#` part of a URL does not reload a page** — relevant when testing.
14. **innerHTML with customer-typed text in admin.** admin's `msg()` used innerHTML, and messages included SKUs, company names and emails that customers type. A customer could have run a script in a staff session (and moved balances). `msg()`/`busy()` are now plain text; never build admin HTML from data — use `textContent`.
15. **Saving a whole row from a page loaded earlier.** The stock editor sent every column on Save, so a stale page could undo dispatches (quantity) or customer edits. Save sends only the fields that changed.
16. **"Signed in" is not "customer".** Anyone can create a Supabase login with the public key. Customer-only functions check `is_customer()`; RLS insert policies must not let customers set staff-owned columns (e.g. `inbound_items.qty_received`).
17. **A `CNAME` file before the DNS record exists** takes the whole site down (GitHub redirects to an address that does not answer). Let GitHub write it from Settings → Pages after DNS is in place.
18. **Relative links on the 404 page.** GitHub serves `404.html` at whatever address was missing (`/a/b/c`), so `panel.html` would resolve to `/a/b/panel.html` and 404 again. The page sets a `<base>` from a tiny script at the top of `<head>` (`/parcel-scanner/` on github.io, `/` on the custom domain). Keep that script first.
19. **The staff app manifest on a customer page.** `panel2.html` linked `manifest.webmanifest`, so a customer who installed it would have got the staff hub. Removed; customer pages have no manifest.

---

## 12. How to test changes

- **SQL**: PGlite (real Postgres in Node, `npm i @electric-sql/pglite`) with stubs for `auth.users`, `auth.uid()`/`auth.jwt()` from `request.jwt.claims`, roles `anon`/`authenticated`/`service_role` (with Supabase's default table grants and `bypassrls` for service_role), `extensions.pgcrypto`, and `storage.buckets`/`storage.objects`/`storage.foldername()`. Replay `supabase-schema.sql` then each phase, re-run the newest phase to prove idempotency, and test as admin, as customer A, as customer B and as anon — especially the failure paths.
- **Pages**: parse every inline script; check `$('id')` references exist, no duplicate IDs, no duplicate or lost functions, no ES6 syntax.
- **Behaviour**: `playwright-core` driving the installed Chrome headless, against a copy of the page served locally with a fake in-browser Supabase (`window.supabase.createClient` returning a client with `from/rpc/auth/storage/functions` backed by sample data, recording every call). Click through each action and assert on the recorded calls; take full-page screenshots at 1440×900 and 390×844 and look at them.
- **Edge Functions**: run the `.ts` files in Node with a `Deno` shim and a fake `fetch`; sign test webhook bodies with HMAC-SHA256 like Stripe.
- **Label parsing**: reportlab test PDFs through the page's parsing functions via pdfjs-dist 3.11.174.
- **Page tags**: for every `.html` check one `<h1`, a unique `<title>`, description, robots and canonical. Test `404.html` with a small local server that serves the repo at both `/` and `/parcel-scanner/` and answers missing paths with `404.html` and status 404.

---

## 13. Ideas discussed but not built

- **Stripe live** (built; needs Mert's Stripe account).
- **Marketplace connections** (eBay/Shopify orders straight into shipments) — needs developer accounts and approvals.
- **Create UK shipping labels** from the panel (Royal Mail Click & Drop API) — needs an account with API access.
- **Turkish/English switch** in the customer panel.
- **Automatic emails** via Resend (free up to 3,000/month) through a Supabase Edge Function (e.g. "your parcel has shipped", "ticket answered").
- **Customer directory import** from a spreadsheet of ~200 customers with shelf numbers. It contains **plain-text passwords**: never import those; recommend a password manager.
- **Root address for customers**: `panel.ecomflex.co.uk/` currently opens the staff hub (with a link to the customer panel). It could open the customer sign-in instead, with the hub moved to its own page. Not done without asking: it changes the staff app's start page.
- **Moving label-reader product names into Supabase.**
- **Supabase Pro**, recommended before real money flows through the ledger.
