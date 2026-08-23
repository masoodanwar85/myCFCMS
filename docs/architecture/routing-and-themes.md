# Routing and Themes (Group 4)

The layer that turns a resolved tenant into HTML — and the point at which the
first three groups become a website you can open in a browser.

Read [multi-tenancy.md](multi-tenancy.md) and [pages.md](pages.md) first.

---

## 1. The completed request flow

Groups 1–3 built the pieces. This one connects them:

```
  GET https://client.com/about/team
        |
   TenantInterceptor        (Group 1)  domain -> Site -> TenantContext
        |
   route  /:path*                      catch-all -> core:Frontend.index
        |
   Frontend handler         (Group 4)  the front controller
        |
   ContentResolverRegistry  (Group 4)  "does anything serve this path?"
        |
   PageContentResolver      (Group 3)  yes: a published page
        |
   ThemeService             (Group 4)  which theme does this site use?
        |
   theme view + layout                 HTML
```

Two decisions Group 1 deliberately postponed are settled here, because they are
routing decisions and routing did not exist yet:

**An unknown domain gets a 404** and Core's own plain page. Not a theme — a
theme is a property of a *site*, and there is no site. The page names the host
and says what to check. Nothing tenant-owned is disclosed.

**A known domain with an unknown path gets a 404 rendered in that site's own
theme**, so a client's 404 looks like their site. If a theme ships no `404`
view, Core's plain one is used rather than turning a missing page into a server
error.

For local development, add `localhost` as a domain of a site. That is the
mechanism Group 1 already provides; there is deliberately no separate
"development fallback site" setting to drift out of sync with it.

---

## 2. How Core routes to content it knows nothing about

Core owns the front controller. Core must **not** depend on Pages, Blog or News.
Those two facts look contradictory until the question is inverted.

Core does not ask *"which page is at this path?"*. It asks every registered
resolver *"can any of you answer for this path?"*:

```cfc
// app/modules/pages/ModuleConfig.cfc
function onLoad(){
    wirebox.getInstance( "ContentResolverRegistry@core" )
           .register( "PageContentResolver@pages", 100 );
}
```

A resolver is any object with one method:

```cfc
struct|null resolveContent( numeric siteId, string path )
```

returning `null` when it does not recognise the path, or a struct describing
what to render:

```cfc
{
    view            : "page",     // a view the theme must provide
    args            : { ... },    // passed to that view
    title           : "About",
    metaDescription : "...",
    navigation      : [ ... ],    // for the layout
    statusCode      : 200
}
```

Resolvers are asked in **priority order, lowest first, and the first answer
wins**. Pages registers at 100 as the catch-all; a Blog module claiming
`/blog/*` will register lower and be asked first.

The payoff: installing or removing a feature module changes what the site can
serve **without a line of Core changing**. It also puts the navigation and
breadcrumb in the resolver's hands — Core could not build those without knowing
what a page tree is, and it does not.

Resolutions are normalised on the way out, so every key is present and a theme
never has to defend against a missing one.

---

## 3. Themes

A theme is a directory under `/themes`, not a database row. Themes are code and
templates deployed with the application; a client *selects* one rather than
authoring it.

```
themes/
    default/
        theme.json          name, version, description
        layouts/main.cfm    receives args.body plus site, title, navigation
        views/page.cfm      receives args.page, args.breadcrumb, args.site
        views/404.cfm       receives args.path, args.site
    starter/
        ...
```

The *selection* is tenant data, so it lives in the site's settings under the key
`theme` — which means per-site theming needed no new table, and Core's theme
layer stays free of any schema of its own.

Rendering goes through ColdBox's `externalView()`, because theme templates sit
outside the application's view conventions on purpose: a theme should be
droppable into `/themes` without touching `app/`.

A layout receives the already-rendered content as `args.body` rather than
fetching it. That keeps a theme a pair of dumb templates with no knowledge of
the request, the tenant, or the module that produced the content.

**A site naming a theme that is not installed falls back to the default and logs
a warning.** A missing theme directory should not take a client's whole site
offline.

`ThemeService.normalizeSlug()` strips anything outside `[a-z0-9_-]`, so a slug
can never climb out of the themes root. `../../etc` becomes `etc`, which is
simply not installed.

Two themes ship, and `starter` exists for a specific reason: with only one
theme, "the site renders through its theme" and "the site renders through the
only theme there is" are indistinguishable. The specs assert that two sites on
the same code render measurably differently.

---

## 4. Routing changes to the scaffold

The ColdBox scaffold's conventions route (`:handler/:action?`) had to go. In a
CMS the public URL space belongs to tenant content, and a conventions route
swallows `/about` as a handler named "about" before the site ever sees it.

`app/config/Router.cfc` now reads, in order:

```cfc
route( '/healthcheck', ... );                    // explicit app routes
route( '/api/echo', ... );
route( '/main/:action?' ).toHandler( 'main' );   // framework-addressable
route( '/' ).to( 'core:Frontend.index' );        // site root
route( '/:path*' ).to( 'core:Frontend.index' );  // public catch-all, LAST
```

`/` needs its own route: `:path*` does not match an empty path, and without it
ColdBox falls through to its default event and serves the framework's welcome
page instead of the tenant's home page.

**Anything the application itself serves must be claimed above the catch-all.**
Admin and API areas will take reserved prefixes here in the same way.

---

## 5. What is implemented

- `ContentResolverRegistry` — priority-ordered, first-answer-wins, with
  normalised resolutions.
- `ThemeService` and `Theme` — per-site selection, manifest reading, fallback,
  slug sanitisation, view and layout rendering.
- `Frontend` handler — the public front controller, and the unknown-domain and
  unknown-path policies.
- `PageContentResolver` in the Pages module, supplying pages, navigation and
  breadcrumbs.
- Two themes, and Core's own tenant-less 404 pages.
- 47 passing specs for this group; 306 across Groups 1–4.

## 6. What is intentionally postponed

| Area | Why it waits |
| --- | --- |
| Page caching / static output | Explicitly out of scope. Every request currently resolves and renders from scratch. This is the obvious first place to measure once there is real traffic. |
| Admin UI | Still services only. Nothing edits content through a browser yet. |
| Permission checks on the front end | Public pages need none. They arrive with the admin area, which is where `AuthorizationService` gets wired to a request boundary. |
| Sitemap, robots.txt, canonical URLs | SEO is its own Core area. `site_domains.is_primary` already records the canonical host for it. |
| Redirects and URL history | Renaming a page silently breaks its old URL. A `page_redirects` table is the natural fix and belongs with the admin UI that makes renaming easy. |
| Per-site timezone in output | `sites.timezone` is stored and unused. Nothing currently renders a date; when something does, it formats in the site's zone. See the datetime note in [pages.md](pages.md). |
| Theme assets pipeline | Themes are self-contained CFML and inline CSS. Bundling, fingerprinting and a CDN are a later concern. |
| Multiple layouts per theme | `renderLayout` already takes a layout name; nothing chooses a non-`main` one yet. |
| Localisation | `sites.locale` reaches the `<html lang>` attribute and stops there. |

---

## 7. Trying it

Add a domain to a site, publish a page, and request it:

```cfc
var site = siteService.createSite( name = "Client One" );
siteService.addDomain( site.getId(), "localhost" );
roleService.seedDefaultRolesForSite( site.getId() );
themeService.setThemeForSite( site.getId(), "starter" );

var home = pageService.createPage( siteId = site.getId(), title = "Home", content = "<p>Hello.</p>" );
pageService.publishPage( home.getId() );
pageService.setHomePage( site.getId(), home.getId() );
```

Then `http://localhost:<port>/` serves it. Against a running server, any domain
can be simulated without DNS:

```bash
curl -H "Host: client-one.test" http://127.0.0.1:<port>/about/team
```
