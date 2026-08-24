# Multi-Tenancy (Group 1)

How myCFCMS hosts many client websites from one application and one database,
what Group 1 actually delivers, and what has deliberately been left for later.

---

## 1. The approach

One application, one MySQL database, many tenants.

A **tenant** is a row in `sites`. Every tenant-owned table from here on carries a
`site_id` column pointing at it. There are no per-client databases, no
per-client schemas and no per-client code paths.

Why a shared database, for a system expected to hold 8–10 client sites and grow:

- **One migration run.** Schema changes apply once. With a database per tenant,
  every migration becomes a fan-out job that can half-succeed.
- **Cross-tenant work stays possible.** A control panel listing every site, or a
  report across clients, is an ordinary query rather than a federation problem.
- **Connection pooling stays sane.** One datasource, not one per client.

The cost is that isolation is enforced by `site_id` in queries rather than by the
database boundary. That is a real trade-off, and it is the reason tenant identity
is resolved in exactly one place and read from exactly one object — see
[TenantContext](#4-tenantcontext).

---

## 2. Database strategy

Three tables, all InnoDB / `utf8mb4` / `utf8mb4_unicode_ci`.

### `sites`

The tenant itself.

| Column | Type | Notes |
| --- | --- | --- |
| `id` | `BIGINT UNSIGNED` | PK, auto-increment |
| `name` | `VARCHAR(150)` | Human-readable |
| `slug` | `VARCHAR(100)` | Unique, stable machine identifier |
| `status` | `VARCHAR(20)` | `active` or `inactive`, `CHECK`-constrained |
| `timezone` | `VARCHAR(64)` | Olson name, defaults `UTC` |
| `locale` | `VARCHAR(20)` | Defaults `en_US` |
| `created_at` / `updated_at` | `DATETIME` | |

Indexes: `uq_sites_slug` (unique), `idx_sites_status`.

**On extra columns:** none were added. Theme, SEO defaults, owner, plan and
feature flags all either belong to a later group or belong in `site_settings`.
Adding them now would mean guessing at shapes we cannot yet verify, and a wrong
guess is more expensive to remove than a missing column is to add.

`status` is `active`/`inactive` only. That covers taking a client offline without
deleting anything, which is the requirement we actually have. A `maintenance`
state can be added when there is a page to render for it.

### `site_domains`

The hostnames that route to a site. A site may own several.

| Column | Type | Notes |
| --- | --- | --- |
| `id` | `BIGINT UNSIGNED` | PK |
| `site_id` | `BIGINT UNSIGNED` | FK → `sites.id`, `ON DELETE CASCADE` |
| `domain` | `VARCHAR(255)` | **Globally unique** |
| `is_primary` | `TINYINT(1)` | Canonical hostname for the site |
| `is_active` | `TINYINT(1)` | Whether it serves traffic |
| `created_at` / `updated_at` | `DATETIME` | |

Two constraints carry most of the weight here:

- **`uq_site_domains_domain`** — a unique index on `domain` alone. This is what
  makes "a domain cannot belong to multiple sites" a guarantee rather than a
  convention. It is enforced by MySQL, so a race between two admins, a bad
  import or a future API endpoint cannot break it. It doubles as the lookup
  index for tenant resolution, so resolving a request is a single-row
  unique-key read.

- **`uq_site_domains_primary`** — a *functional* unique index over
  `CASE WHEN is_primary = 1 THEN site_id END`. Non-primary rows evaluate to
  `NULL`, and MySQL does not compare `NULL`s in a unique index, so a site can
  hold many secondary domains but only ever one primary. Without this, "the
  canonical URL for this site" would be ambiguous, which matters directly for
  SEO and link building later.

  *Requires MySQL 8.0.13+.*

`client.com` and `www.client.com` are **separate rows**, deliberately. Which one
is canonical is an editorial decision per client, not something the CMS should
assume, so domain normalisation never strips a `www.` prefix.

### `site_settings`

Tenant-scoped configuration as key/value.

| Column | Type | Notes |
| --- | --- | --- |
| `id` | `BIGINT UNSIGNED` | PK |
| `site_id` | `BIGINT UNSIGNED` | FK → `sites.id`, `ON DELETE CASCADE` |
| `setting_key` | `VARCHAR(191)` | |
| `setting_value` | `TEXT` | Nullable |
| `created_at` / `updated_at` | `DATETIME` | |

Unique on `(site_id, setting_key)`, so writes are an upsert and a key can hold
exactly one value per site.

Key/value rather than dozens of columns: settings differ per client and every
future module brings its own. Widening a shared table for each new toggle does
not scale across the module set this CMS is heading towards.

`setting_key` is 191 characters so the composite unique index stays comfortably
inside InnoDB's key-length limit under `utf8mb4`. Values are stored as text and
callers own their interpretation — there is no type system on settings, and
adding one before we know what types are needed would be speculation.

Both child tables cascade on delete, so removing a site removes its domains and
settings with it and cannot leave orphans behind.

---

## 3. Tenant resolution flow

```
        Request
           |
           v
  TenantInterceptor.preProcess          (app/modules/core/interceptors)
           |
           v
  TenantResolver.resolveFromEvent       Host header -> CGI fallback
           |
           v
  DomainNormalizer.normalize            lower-case, strip scheme/port/path/dot
           |
           v
  SiteRepository.findActiveByDomain     JOIN site_domains -> sites
           |                            (domain active AND site active)
           v
      Site  or  null
           |
     +-----+------------------+
     |                        |
   found                  not found
     |                        |
     v                        v
 TenantContext          context left empty
 prc.currentSite        announce onTenantNotResolved
 announce
 onTenantResolved
     |
     v
  Handler / Service / View
```

The interceptor runs on `preProcess`, so the tenant is established before any
handler, service or view executes. It is the **only** trigger point for
resolution in the application.

`TenantResolver` itself is pure lookup — no request state, no side effects, no
writing to the context. That keeps it callable from a CLI task or a test with a
bare hostname string, and leaves policy decisions to the interceptor.

**Unknown domains** do not fail the request. The context is left empty and
`onTenantNotResolved` is announced. Deciding what an unrecognised host should
actually see — a 404, a landing page, a redirect to a default site — is a routing
concern, and routing is not in Group 1. Making that decision now would mean
hard-coding a policy we would have to unpick later.

**A site resolves only if both the domain and the site are usable**: an inactive
domain, or any domain on an inactive site, resolves to nothing. That is what lets
an operator take a client offline without deleting a single row.

---

## 4. TenantContext

`TenantContext` is the single answer to *"which site is this request for?"*

```cfc
property name="tenantContext" inject="TenantContext@core";

var site   = tenantContext.getCurrentTenant();      // throws if unresolved
var siteId = tenantContext.getCurrentTenantId();    // scopes tenant-owned queries
var maybe  = tenantContext.getCurrentTenantOrNull(); // null-tolerant read
```

The point of it is what it prevents. Without a central context, every handler
that needs to know the tenant re-derives it from the host, and within a few
modules there are several slightly different copies of that logic — one of which
gets the `www.` case wrong, or forgets the port, or forgets to check whether the
site is active. Tenant identity is the thing that keeps one client's data off
another client's website, so it is resolved once, in one place, and read
everywhere else.

**Why a singleton over `request` scope, rather than a request-scoped object.**
A request-scoped WireBox object injected into a singleton service is captured at
the singleton's creation and then goes stale on every subsequent request — the
classic scope-widening injection bug, and a particularly nasty one here because
the symptom is a request being served another tenant's data. Because this object
keeps its state in the `request` scope instead, it can be injected anywhere, into
any scope, and always reports the current request's tenant. No provider wrapper,
no ordering rules for future contributors to remember.

`clear()` is called at the start of every request, before resolution, so a pooled
thread can never inherit the previous request's tenant.

`getCurrentTenant()` throws `Tenancy.NoCurrentTenant` rather than returning null,
so code that assumes a tenant fails loudly and immediately instead of silently
querying with an empty `site_id`.

---

## 5. Code layout

```
app/modules/core/                     Core: infrastructure only.
    ModuleConfig.cfc                    Never depends on a feature module.
    interceptors/
        TenantInterceptor.cfc         Request -> tenant, once, before handlers.
    models/
        persistence/
            BaseRepository.cfc        Shared generated-key / unique-violation helpers.
        tenancy/
            Site.cfc                  Entities: state only, no persistence,
            SiteDomain.cfc              no rendering, no request awareness.
            SiteSetting.cfc
            SiteRepository.cfc        SQL lives here and nowhere else.
            SiteDomainRepository.cfc
            SiteSettingsRepository.cfc
            SiteService.cfc           Use cases: validate + orchestrate.
            DomainNormalizer.cfc      One definition of a canonical hostname.
            TenantContext.cfc         The current tenant.
            TenantResolver.cfc        Hostname -> Site. Pure lookup.
```

Models sit under `models/tenancy/` rather than flat in `models/`, because Core
will also hold auth, permissions, media, SEO and shortcodes. ColdBox's
`autoMapModels` maps by component name regardless of subfolder, so the WireBox
aliases are unaffected: `SiteService@core`, `TenantContext@core`, and so on.

The layering the whole design depends on:

```
Handler / API endpoint / future GraphQL resolver
        |
     Service          validation + orchestration, no HTML, no HTTP
        |
   Repository         all SQL, entities in and entities out
        |
    Database
```

Nothing in this group renders anything. `SiteService.createSite()` is the same
call whether it is reached from a server-rendered admin form, a REST endpoint or
a GraphQL mutation — which is the requirement that made the split worth having.

### Extension points

Feature modules should listen to these rather than resolving tenants themselves:

| Point | Data | Fired when |
| --- | --- | --- |
| `onTenantResolved` | `{ site }` | A request was attributed to a site |
| `onTenantNotResolved` | `{ domain }` | The host matched no active site |

### Configuration

`app/modules/core/ModuleConfig.cfc`:

| Setting | Default | Purpose |
| --- | --- | --- |
| `ignoredDomains` | `[]` | Hostnames that are never tenants (health checks, an admin hostname). Skipped before any database lookup. |

---

## 6. What is implemented

- `sites`, `site_domains`, `site_settings` — migration, indexes, foreign keys,
  `CHECK` constraint, cascade deletes.
- Entities, repositories and a service layer for all three.
- `DomainNormalizer` — one canonical definition of a hostname.
- `TenantResolver` — hostname → active site, or null.
- `TenantContext` — request-scoped current tenant, injectable anywhere.
- `TenantInterceptor` — wires resolution into `preProcess`.
- `onTenantResolved` / `onTenantNotResolved` interception points.
- 85 passing specs for this group (unit + integration against real MySQL); 188 across Groups 1 and 2.

## 7. What is intentionally postponed

Not built, and not stubbed out either — there are no placeholder files for any
of this:

| Area | Why it waits |
| --- | --- |
| Users, roles, permissions | **Delivered in Group 2** — see [access-control.md](access-control.md). |
| Pages | **Delivered in Group 3** — see [pages.md](pages.md). |
| Blog | **Delivered in Group 6** — see [blog.md](blog.md). |
| Contact | **Delivered in Group 7** — see [contact-and-editing.md](contact-and-editing.md). |
| News | A feature module. Core must not know it exists. |
| Themes | **Delivered in Group 4** — see [routing-and-themes.md](routing-and-themes.md). |
| Media, SEO, menus, shortcodes | Later Core areas. |
| REST API / GraphQL | The service layer is already shaped for them; no endpoints yet. |
| Routing policy for unknown domains | **Settled in Group 4** — see [routing-and-themes.md](routing-and-themes.md). |
| Caching of domain → site lookups | Explicitly out of scope. The lookup is a single-row unique-index read; add caching when measurement says to, not before. |
| Soft deletes on `sites` | No requirement yet. `status = inactive` covers taking a client offline. |
| Typed / structured settings | Values are text. Adding a type system before knowing the needed types would be speculation. |
| Automatic `site_id` scoping in queries | Deliberate: Group 1 has no tenant-owned content tables yet. Worth revisiting as a query-builder concern once there are. |

---

## 8. Running it

```bash
box migrate status      # what is applied
box migrate up          # apply
box migrate down        # roll back the last migration
```

Migrations read connection settings from `.env` via `.cbmigrations.json`.

**Do not run `box migrate --verbose`** unless you intend to print the database
password to your console — the flag dumps the resolved `connectionInfo` struct in
plaintext.

Tests:

```bash
box server start
open http://127.0.0.1:<port>/tests/runner.cfm
```

The integration specs need migrations to have run. Every row they create uses a
`zzt-` slug prefix and is deleted afterwards.
