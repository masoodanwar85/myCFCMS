# myCFCMS

A multi-tenant CMS built on ColdBox 8 (HMVC), ColdFusion 2025 and MySQL.

One application and one database host many client websites. A request's tenant
is resolved from its hostname once per request and read from a central
`TenantContext` everywhere else.

## Status

| Group | Scope | State |
| --- | --- | --- |
| 1 | Multi-tenancy foundation — `sites`, `site_domains`, `site_settings`, tenant resolution, `TenantContext` | **Done** |
| 2 | Identity and access — `users`, `roles`, `permissions`, authorization | **Done** |
| 3 | Pages module — hierarchy, paths, publishing, per-page SEO | **Done** |
| 4 | Routing and themes — public front controller, per-site themes | **Done** |
| 5 | Admin UI — authentication, request-boundary authorization, CRUD | **Done** |
| 6 | Content sanitising + Blog module — posts, categories, archives | **Done** |
| 7 | Contact module + CKEditor 5 rich text editing | **Done** |
| 8 | Media library, editor image uploads, mail layer | **Done** |
| 9 | SEO — canonical addresses, per-tenant sitemap and robots, social tags | **Done** |
| 10 | Menus — editable per-site navigation, with the automatic menu as a fallback | **Done** |
| 11 | Shortcodes — expansion seam, with Core, Media and Blog handlers | **Done** |
| 12 | REST API — token auth, one envelope, module-declared resources | **Done** |
| 13 | Per-page SEO, social, sitemap and scheduling controls | **Done** |
| 14+ | Password reset, News, search, revisions | Not started |

## Architecture

A modular monolith. `app/modules/core` holds infrastructure — multi-tenancy,
authentication data, authorization, and later routing, themes, SEO and media.
Feature modules live beside it and depend on Core only; Core never depends on
them. `app/modules/pages` is the first, and the template the rest follow.

```
Request -> Handler -> Service -> Repository -> Database
```

Business logic lives in the service layer and renders nothing, so the same
services can back server-rendered sites, the REST API and a future GraphQL layer.

Architecture documentation:

- [multi-tenancy.md](docs/architecture/multi-tenancy.md) — tenant resolution, `TenantContext`, the database strategy.
- [access-control.md](docs/architecture/access-control.md) — users, per-site roles, permissions, authorization.
- [pages.md](docs/architecture/pages.md) — the first feature module: page tree, paths, publishing.
- [routing-and-themes.md](docs/architecture/routing-and-themes.md) — the public request flow, content resolvers, themes.
- [frontend-request.md](docs/architecture/frontend-request.md) — the live request, from Host header to themed HTML.
- [admin.md](docs/architecture/admin.md) — authentication, the security boundary, CSRF, admin screens.
- [blog.md](docs/architecture/blog.md) — content sanitising, and the Blog module as a test of the module seams.
- [contact-and-editing.md](docs/architecture/contact-and-editing.md) — rich text editing, and the first publicly writable module.
- [media-and-mail.md](docs/architecture/media-and-mail.md) — uploads, safe file serving, and the mail layer.
- [seo-and-menus.md](docs/architecture/seo-and-menus.md) — canonical addresses, sitemaps, robots, and editable navigation.
- [shortcodes-and-api.md](docs/architecture/shortcodes-and-api.md) — shortcode expansion, API tokens, and the REST boundary.
- [deployment/apache-modjk.md](docs/deployment/apache-modjk.md) — deploying behind Apache + mod_jk, and why the rewrite rules cannot live in `.htaccess`.
- [guides/adding-a-site.md](docs/guides/adding-a-site.md) — provisioning a second site on the same instance.

Each records what is implemented and what is deliberately postponed.

## Getting started

```bash
box install
cp .env.example .env      # then set DB_PASSWORD and create the database
box migrate up
box server start
```

## Tests

```bash
box server start
```

Then open `/tests/runner.cfm` on the reported port. Integration specs require
migrations to have run.

## Layout

```
app/            ColdBox application (config, handlers, models, modules, views)
lib/            Framework and dependencies — not in version control
public/         Web root
resources/      Database migrations and seeds
tests/          TestBox specs
docs/           Architecture documentation
```
