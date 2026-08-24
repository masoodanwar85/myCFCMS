# Frontend Request Workflow

The path a public request takes from Host header to HTML. Host first, then
path, then theme. Core owns the front controller and knows nothing about
pages, posts or forms — it asks registered modules whether any of them can
serve the path.

This is a walkthrough of the live request, not a new group. The pieces it
connects are documented in [multi-tenancy.md](multi-tenancy.md),
[pages.md](pages.md) and [routing-and-themes.md](routing-and-themes.md).

---

## 1. The path in full

```
GET https://client.com/about/team
        |
        v
public/Application.cfc               ColdBox bootstrap (onRequestStart)
        |
        v
TenantInterceptor.preProcess         Host -> Site -> TenantContext
        |
        v
Router                               reserved prefixes, then the catch-all
        |
        +-- /admin...                admin module  (not this flow)
        +-- /media/:path*            core:Media.serve
        +-- /  or  /:path*           core:Frontend.index
                    |
                    v
            Frontend.index
                    |
                    +-- no tenant    Core 404, plain, no theme
                    |
                    +-- POST         ContentResolverRegistry.resolveSubmission()
                    |                  (contact form; may relocate)
                    |
                    +-- GET          ContentResolverRegistry.resolve()
                    |                  first resolver that answers wins
                    |
                    +-- miss         RedirectService.find()
                    |                  then a themed 404
                    |
                    +-- hit          theme view + theme layout -> HTML
```

The architectural rule that makes this hang together: **Core owns the front
controller and knows nothing about pages.** Installing or removing Blog or
Contact changes what a site can serve without a line of Core changing.

---

## 2. Bootstrap

Every request enters through `public/Application.cfc`. `onRequestStart` hands
it to ColdBox.

There is no conventions route (`:handler/:action?`). In a CMS the public URL
space belongs to tenant content, and a conventions route would swallow
`/about` as a handler named "about" before the site ever saw it. Anything the
application itself serves must be claimed as an explicit route above the
catch-all.

---

## 3. Tenant from the Host header

`TenantInterceptor` runs in `preProcess`, before any handler:

1. Clears `TenantContext`, so a pooled thread cannot leak the previous site.
2. Reads the `Host` header (then CGI fallbacks), normalises it, and looks up
   an **active domain of an active site**.
3. On a match, stores the site in request-scoped `TenantContext` and sets
   `prc.currentSite`.
4. On no match, leaves the context empty and announces `onTenantNotResolved`.
   That is not an error here — the handler decides what to show.

Handlers never inspect the host. Feature modules never resolve tenants
themselves. Domain parsing happens once, in one place; everything else asks
`TenantContext`.

The interceptor's state lives in the `request` scope, not in a request-scoped
WireBox object. A request-scoped object injected into a singleton would be
captured at creation and go stale; because the state is on `request`, the
context can be injected anywhere and always reports this request's tenant.

For local development, add `localhost` as a domain of a site. There is
deliberately no separate "development fallback site" setting to drift out of
sync with that.

---

## 4. Routing: reserved prefixes, then the catch-all

`app/config/Router.cfc` matches in this order:

| Route | Destination |
| --- | --- |
| `/healthcheck`, `/api/echo`, `/main/:action?` | App / framework |
| `/admin…` | Admin module entry points, prepended then sorted longest-first |
| `/media/:path*` | `core:Media.serve` — files live outside the webroot |
| `/` | `core:Frontend.index` (empty path; `:path*` would not match) |
| `/:path*` | `core:Frontend.index` — **must stay last** |

`/` needs its own route: `:path*` does not match an empty path, and without it
ColdBox falls through to its default event and serves the framework's welcome
page instead of the tenant's home page.

Module entry points are prepended as modules load, so the table would otherwise
end up in reverse load order. `ModuleRouteOrderInterceptor` re-sorts them
longest-pattern-first after every module has registered, so `/admin/contact`
cannot be swallowed by `/admin`. See [admin.md](admin.md).

Uploaded files are a public URL but not content. They are served by
`core:Media.serve`, scoped to the current tenant, because they live under
`storage/` rather than `public/`. See [media-and-mail.md](media-and-mail.md).

---

## 5. The front controller: `Frontend.index`

This is the only public content handler. It owns four decisions.

**Unknown domain.** No tenant → HTTP 404 and Core's own
`frontend/unknownDomain` view, with **no layout and no theme**. A theme is a
property of a site, and there is no site. The page names the host and says
what to check. Nothing tenant-owned is disclosed.

**Known domain.** Load the site's theme from site settings. A missing or
uninstalled slug falls back to `default` and logs a warning — a missing theme
directory should not take a client's whole site offline.

**POST.** Ask `ContentResolverRegistry.resolveSubmission()` *before* the GET
lookup, so a module can answer with a result page or the form again carrying
errors. Contact is the only resolver that implements `handleSubmission`. A
successful post returns `redirectTo` (typically `/contact/thank-you`) so a
refresh cannot send it twice. See
[contact-and-editing.md](contact-and-editing.md).

**GET.** Ask `resolvers.resolve(siteId, path)`. The path is lowercased and
stripped of leading and trailing slashes. An empty path is the site root.

---

## 6. Content: first resolver that answers wins

Core does not ask *"which page is at this path?"*. It asks every registered
resolver *"can any of you answer for this path?"*:

```cfc
// app/modules/pages/ModuleConfig.cfc
wirebox.getInstance( "ContentResolverRegistry@core" )
       .register( "PageContentResolver@pages", 100 );
```

A resolver is any object with `resolveContent(numeric siteId, string path)`,
returning `null` when it does not recognise the path, or a struct describing
what to render. Resolutions are normalised on the way out, so every key is
present and a theme never has to defend against a missing one:

```cfc
{
    view            : "page",     // a view the theme must provide
    args            : { ... },    // passed to that view
    title           : "About",
    metaDescription : "...",
    statusCode      : 200,
    redirectTo      : ""
}
```

Resolvers are asked in **priority order, lowest first, and the first answer
wins**. A module claiming a specific prefix registers a lower number than
Pages, which is the catch-all:

| Resolver | Priority | Claims |
| --- | --- | --- |
| `BlogContentResolver` | 50 | `/blog`, `/blog/page/N`, `/blog/category/{slug}`, `/blog/{slug}` |
| `ContactContentResolver` | 60 | `/contact`, `/contact/thank-you` |
| `PageContentResolver` | 100 | everything else, including `/` via the home-page setting |

So `/blog` stays a blog even if a page happens to have that slug. Anything
outside a module's base path is declined, and the next resolver gets its turn.

Pages looks up a **published** page by the materialised `path` column —
`UNIQUE (site_id, path)`, one unique-index read. The empty path uses the
`pages.homePageId` site setting, and only if that page is published: a draft
home page must not silently become the front door. See [pages.md](pages.md)
and [blog.md](blog.md).

---

## 7. Missed path: redirect, then themed 404

If no resolver claims the path, `RedirectService.find()` runs **before** 404.
Renames — pages and posts — record `site_redirects` so a link someone already
published keeps working rather than becoming a 404. Redirects live in Core,
not in Pages: a visitor arriving on an old URL has no idea which module used
to answer it, and any module's content can move.

Recording `A -> B` collapses chains at write time rather than following them
at request time, so every redirect is exactly one hop. See
[routing-and-themes.md](routing-and-themes.md#7-old-urls-after-content-moves).

Still nothing → HTTP 404 rendered in **that site's own theme** (`404` view +
`main` layout), so a client's missing page looks like their site. If the
theme ships no `404` view, Core's plain `frontend/notFound` is used rather
than turning a missing page into a server error. The 404 keeps the site's
menu, so a reader can get somewhere.

---

## 8. Navigation is not a resolver's business

A content resolver describes **content**. The site's menu is **chrome**, and
it comes from a second registry.

That distinction was learned the hard way: navigation was originally part of
the resolution, supplied by whichever module answered the URL. The Pages
resolver built it from the page tree, and the Blog resolver — which cannot
see the page tree, and should not be able to — supplied nothing. The result
was a menu that appeared on pages and silently vanished on the blog.

`SiteNavigationRegistry` asks every registered provider, independently of
what served the request:

```cfc
array getNavigationItems( numeric siteId )
// -> [ { label : "About", href : "/about", order : 1 } ]
```

Items are **structs, not entities**. A theme should not have to know that one
item is a Page and another is a module's landing link. Items are merged and
sorted by each item's own `order`, then by label — so a module's entry can
sit between two pages rather than being stuck after whichever provider ran
last. The menu is identical on a page, a blog post, a category archive and a
404.

A provider that throws is skipped with a warning rather than taking the page
down: a broken menu is a poor experience, a blank site is worse.

---

## 9. Render: view first, then layout

On a hit:

1. `ThemeService.renderView()` renders the theme template
   (`themes/{slug}/views/{view}.cfm`) through ColdBox `externalView()`.
   Themes sit outside `app/` on purpose: a theme should be droppable into
   `/themes` without touching the application.
2. `SiteNavigationRegistry.getNavigationFor(siteId)` builds the menu from
   every provider.
3. `ThemeService.renderLayout()` wraps the already-rendered HTML as
   `args.body`, plus `site`, `title`, `metaDescription`, `navigation` and
   `path`.

The layout is a pair of dumb templates. It does not know the request, the
tenant resolution, or which module produced the body.

A typical page therefore looks like:

- **Layout** (`themes/default/layouts/main.cfm`) — chrome, `<title>`, nav
- **View** (`themes/default/views/page.cfm`) — breadcrumb, title, HTML content

A site naming a theme that is not installed falls back to `default`.
`ThemeService.normalizeSlug()` strips anything outside `[a-z0-9_-]`, so a
slug can never climb out of the themes root.

Use `xmlFormat()` for a URL in an attribute, and `encodeForHTML()` for text.
ColdFusion's `encodeForHTMLAttribute` entity-encodes `/`, `?` and `=`, which
works in a browser and looks wrong in the markup. See
[routing-and-themes.md](routing-and-themes.md#8-encoding-urls-in-a-theme).

---

## 10. What this flow is not

| Concern | Where it lives |
| --- | --- |
| Admin screens | `/admin` is a separate module entry point, with its own handlers and layout. See [admin.md](admin.md). |
| Uploaded files | `/media/...` is `Media.serve`, scoped to the current tenant. See [media-and-mail.md](media-and-mail.md). |
| Page caching | Every request currently resolves and renders from scratch. Explicitly out of scope. |
| Front-end permission checks | Public pages need none. Authorization is an admin-boundary concern. |
| Current-item highlighting | Providers return `label`, `href` and `order`; nothing tells a theme which entry matches the current URL. |
| Menu management | Navigation is assembled from providers. A site cannot yet reorder or hide entries. |
