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

The live request — bootstrap, reserved prefixes, POST, redirects, navigation
and the 404 policies — is walked end to end in
[frontend-request.md](frontend-request.md).

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

### Navigation is not a resolver's business

A content resolver describes **content**. The site's menu is **chrome**, and it
comes from a second registry.

That distinction was learned the hard way: navigation was originally part of the
resolution, supplied by whichever module answered the URL. The Pages resolver
built it from the page tree, and the Blog resolver — which cannot see the page
tree, and should not be able to — supplied nothing. The result was a menu that
appeared on pages and silently vanished on the blog.

`SiteNavigationRegistry` fixes the shape rather than the symptom. Core asks
every registered provider, independently of what served the request:

```cfc
// app/modules/pages/ModuleConfig.cfc
wirebox.getInstance( "SiteNavigationRegistry@core" )
       .register( "PageNavigationProvider@pages", 10 );
```

A provider answers one method:

```cfc
array getNavigationItems( numeric siteId )
// -> [ { label : "About", href : "/about", order : 1 } ]
```

Items are **structs, not entities**. A theme should not have to know that one
item is a Page and another is a module's landing link, and a module contributing
an entry should not have to invent an entity to do it.

Items are merged and sorted by each item's own `order`, then by label — so a
module's entry can sit between two pages rather than being stuck after whichever
provider ran last. The menu is now identical on a page, a blog post, a category
archive and a 404.

Blog contributes a single `Blog` entry, and only when the site has a published
post: an empty archive in the menu is a dead end. There is no menu management
yet — Menus remains a postponed Core area — so a module contributing its own
landing link is how its section becomes findable at all. When menu editing
arrives, these become defaults an editor can remove.

A provider that throws is skipped with a warning rather than taking the page
down: a broken menu is a poor experience, a blank site is worse.

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

## Page templates

A page renders through the theme's `page` view by default. When it needs its own
logic — a fee calculator, a live listing, anything assembled at request time —
it can name a **template** instead:

    themes/willcreator/templates/fee-calculator.cfm

The author picks it from a dropdown on the page's Advanced tab. The picker lists
whatever `.cfm` files are in that directory, so a developer adds a template by
deploying a file; there is nothing to register.

A template receives the same `args` a view does — `args.page`, `args.breadcrumb`,
`args.site`, `args.theme` — and is ordinary CFML, so it can reach any service
through WireBox. The page's title, slug, SEO settings, menu position and publish
window are untouched: a template changes how the body is drawn and nothing else.

`themes/default/templates/example.cfm` is a working one, written to be copied.

### Why a name, and never the code

The obvious alternative is a column holding CFML that the CMS executes. It would
be arbitrary code execution for anyone holding `pages.update`.

`content.unfiltered` can gate raw HTML because HTML runs in the **visitor's**
browser. CFML would run on the **server**, as the ColdFusion user, with the
application's datasource — so an editor on one client's site could read the
credentials and with them every other client's pages, users and enquiries, plus
any file the ColdFusion user can reach. That is not a permission that can be
scoped, because the code runs inside the boundary the permissions exist to
protect rather than behind it.

Storing a name costs nothing by comparison. Theme files already execute on every
request and are deployed by whoever deploys code, so this adds no new surface at
all.

The name is reduced to `[a-z0-9_-]` **twice** — once by `PageService` before it
is stored, and again by `Theme` when the path is built. Two passes because a row
can reach `pages` from a migration, a seed or a direct `UPDATE`, not only through
the service.

### Choosing between the three

| Reach for | When |
|---|---|
| **Shortcode** | A dynamic fragment inside prose an author is writing. |
| **Page template** | One page with its own layout and logic, chosen per page. |
| **A module with a resolver** | It is an application, not a page — its own URLs, its own storage. |

### When a template is missing

Named but not installed, the page falls back to the standard view and
`Frontend` logs a warning. A theme change or a renamed file should leave a page
rendering plainly and be noisy in the log, not take a client's page down over a
display choice. Same rule `ThemeService` already applies to a missing theme.

`template` is part of the resolution contract, normalised in
`ContentResolverRegistry` like `view` and `canonicalPath`, so Blog or any other
module can offer the same thing without Core changing again.

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
| Admin UI | **Delivered in Group 5** — see [admin.md](admin.md). |
| Permission checks on the front end | Public pages need none. The admin area wired `AuthorizationService` to a request boundary in Group 5. |
| Sitemap, robots.txt, canonical URLs | SEO is its own Core area. `site_domains.is_primary` already records the canonical host for it. |
| Redirect management UI | Redirects are recorded automatically on rename (see below); an editor cannot yet add or remove one by hand. |
| Per-site timezone in output | `sites.timezone` is stored and unused. Nothing currently renders a date; when something does, it formats in the site's zone. See the datetime note in [pages.md](pages.md). |
| Theme assets pipeline | Themes are self-contained CFML and inline CSS. Bundling, fingerprinting and a CDN are a later concern. |
| Multiple layouts per theme | `renderLayout` already takes a layout name; nothing chooses a non-`main` one yet. |
| Menu management | Navigation is assembled from providers, and a site cannot yet reorder or hide entries. That is the Menus area, and `SiteNavigationRegistry` is what it will build on. |
| Marking the current item in the menu | Providers return `label`, `href` and `order`; nothing tells a theme which entry matches the current URL. |
| Localisation | `sites.locale` reaches the `<html lang>` attribute and stops there. |

---

## 7. Old URLs after content moves

Renaming a page moved its URL and every URL beneath it, and nothing recorded the
old one. Links a client had already published, and everything a search engine had
indexed, began returning 404 the moment an editor tidied a title. Silent damage
to work that was already correct.

`site_redirects` and `RedirectService` now record the move. Core's front
controller consults them **before** serving a 404, so an unknown path is still a
404 and only a genuinely moved one redirects.

Redirects live in Core, not in Pages: any module's content can move, and a
visitor arriving on an old URL has no idea which module used to answer it. Both
Pages and Blog record their own moves through it.

The hard part is not storing a row — it is not accumulating a maze. Recording
`A -> B`:

1. **removes any redirect away from B**, because B resolves on its own now and a
   redirect from it would be a loop;
2. **repoints anything already aimed at A** so it aims at B, collapsing chains
   instead of following them at request time;
3. replaces any existing redirect from A.

That order matters, and getting it wrong was not theoretical: with the repoint
first, renaming a page **back** to a name it held before turned an existing row
into a redirect to itself and the write failed outright. A `CHECK` constraint
refuses a self-redirect at the database level too, so the invariant does not
depend on the service alone.

Renaming a parent records a redirect for every descendant as well, computed from
the same prefix swap the database rewrite performs, so the two cannot drift.

## 8. Encoding URLs in a theme

Use `xmlFormat()` for a URL in an attribute, and `encodeForHTML()` for text.

ColdFusion's `encodeForHTML` and `encodeForHTMLAttribute` both entity-encode `/`,
`?` and `=`, so a path came out as `href="&##x2f;about&##x2f;team"`. Browsers
decode that and the link works, which is exactly why it survived unnoticed —
it is only visible when you read the markup. `xmlFormat` escapes `&`, `<`, `>`
and `"`, which is what a double-quoted attribute actually needs, and leaves the
path readable.

## 9. Trying it

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
