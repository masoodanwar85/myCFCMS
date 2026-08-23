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
| 5+ | Admin UI, Blog, News, Contact, Media, REST API | Not started |

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
