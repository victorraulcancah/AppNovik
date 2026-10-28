---
version: 1
slug: "lib-presentation-pages-main-shell-page-dart"
primary_target: "lib/presentation/pages/main_shell_page.dart"
related_targets: ["lib/presentation/pages/login_page.dart"]
---

# Surface brief: app shell, navigation and login

Mode: Operate. Platform: Android and iOS, Flutter, Material 3 on both. Phone and tablet.

Audience and job: any user with permissions in a company on 7power; sign in, see only the modules their company has enabled, move between them quickly. Frequent, repeated use.

Constraints: the module list comes from the session context; touch targets 48 dp; system font scale; dark theme first-class; Spanish (Peru).

Unresolved: Novik logo and brand color (seed is provisional); home module.

## Direction contract

THESIS: Plain Material 3, executed with craft; the surface refuses any decorative "world" and lets the company name and the data lead.

OWN-WORLD: Tonal Material 3 surfaces from one blue seed (#1D4ED8), light and dark schemes from the same seed; filled search bar, 40 dp circular leading icons on tonal container, 28 dp pill navigation indicator, status in color roles (error for out of stock, tertiary for low).

STORY: The user signs in and immediately knows whose data this is (company name under the screen title) and what they can do (only enabled modules in the bar).

FIRST VIEWPORT: Top app bar with the screen title and the company name beneath it; filled search field; list rows of 72 dp with leading tonal circle, title and subtitle left, value and caption right; bottom navigation bar of up to five destinations on phone, navigation rail on tablet.

FORM: Category standard, chosen on the decision round (canon card); seed: seed:16dfc194b909d37d. Sketch: .impeccable/mocks/decision/canon.html.

FINISH: unreviewed and undocumented is unfinished; this build ends with the finish review, the verdict, DESIGN.md, and every shipping raster carrying its provenance
