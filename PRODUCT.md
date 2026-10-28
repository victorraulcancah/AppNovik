# Product

<!-- impeccable:product-schema 1 -->

## Platform

android

Flutter app, Material 3 on both Android and iOS (the user chose one Material 3 design for both). iOS still owes its OS guarantees: safe-area insets, edge-swipe back, Reduce Motion. Phones and tablets are both targets.

## Stack

Flutter (Dart), Clean Architecture + Provider. Already in place; see `docs/ARQUITECTURA.md`.

## Users

Anyone who has permissions: the app serves every user of a company in 7power, and the menu shows only the modules their company has enabled and they may use. Roles vary (vendedor, gerente, etc.), so no single persona leads; screens must work for both quick lookups in the field and review at a desk. Each user belongs to exactly one company and sees only that company's data.

## Product Purpose

Novik is the mobile companion to the 7power web system (sales, stock, products, documents, reports). A user signs in, lands in the system, and works with their own company's data from a phone or tablet. Success: the day-to-day tasks of the web (consult products and stock, sales, documents, reports) are quick and reliable on a phone.

## Positioning

Multi-company by design: one app, many companies, each seeing only their own data and only the modules they contracted. Unlike a generic ERP viewer, the navigation is built from what the backend says the company and user are allowed to use.

## Operating Context

- Backend: 7power (Laravel API, Sanctum tokens). Web front: 7power-front.
- Login with `usuario` and `password`; `POST /auth` returns the user, company, plan, warehouses, permissions and enabled modules.
- Companies are on plans with limits (documents, warehouses, e-commerce, customer statements).
- First modules (in order): Producto, Stock, Ventas, Documentos, Reportes. See `docs/MODULOS.md`.
- Phones and tablets; phone gets a bottom navigation bar, tablet a navigation rail.

## Capabilities and Constraints

- Menu and features come from the session context, never a fixed list.
- All data is scoped to the user's company; switching accounts must clear local data.
- First delivery of each module is read-only; create/edit actions come later.
- Undecided: whether one person may work in several companies (today a user belongs to one); whether "Stock" includes "Stock Inteligente"; which module is the home screen.
- Product endpoints take `company_id` from the client; this needs a backend check (see open issues in `docs/MODULOS.md`).

## Brand Commitments

Name: **Novik**. No visual identity exists yet: the user chose to create a new Novik identity for the app rather than follow the web (black with orange/red accents, 7Power logo). Any colors, logo and type used so far are provisional placeholders.

## Evidence on Hand

- Real backend and web front in `C:\laragon\www\novik\7power` and `7power-front` (screens and flows to learn from, not a visual authority).
- No Novik logo, brand colors or photography exist. Do not fabricate customers, metrics or testimonials.

## Product Principles

1. Company context is always visible and always respected: the user should never doubt whose data they are looking at.
2. Show only what the user may use; hide the rest instead of explaining it.
3. Fast to read in the field: key numbers and states are scannable at a glance, one-handed.
4. Same system for phone and tablet: layout adapts, behavior and vocabulary do not.
5. Read-only first, then actions; never ship a half-working write path.

## Accessibility & Inclusion

Material 3 baselines: 48 dp touch targets, system font scale respected (sp), dark theme as a first-class scheme, sufficient contrast. Spanish (Peru) interface.
