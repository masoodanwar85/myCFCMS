# Adding a site

The application is multi-tenant. A second site is not a second deployment, a
second database or a copy of the code — it is a row in `sites`, one or more
rows in `site_domains`, and content scoped to that `site_id`. One application
instance serves all of them.

## How a request finds its tenant

    Host header  ->  TenantResolver  ->  Site  ->  TenantContext  ->  everything else

`TenantResolver` normalises the incoming hostname and looks it up in
`site_domains`. `TenantInterceptor` puts the result in `TenantContext`, and from
that point every repository, service and view is already scoped. No handler
asks "which site is this?" — by the time one runs, the question is answered.

Two consequences worth internalising:

- **A domain belongs to exactly one site.** `addDomain()` refuses a hostname
  that is already assigned, because the mapping has to be unambiguous.
- **An unknown hostname resolves to nothing**, and the request 404s. Pointing
  DNS at the server is not enough; the hostname has to be registered.

## The primary domain

Each site has exactly one primary domain. It is not cosmetic — canonical URLs,
`sitemap.xml` and the Open Graph tags are all built from it. Everything a
search engine sees comes from that one value.

Additional domains still serve traffic. Add `www.` and any local alias as
non-primary, so the site can be opened in development without faking a `Host`
header while nothing public ever mentions `localhost`.

## Provisioning

There is no "create site" screen in the admin: a tenant boundary is not
something one tenant's staff should be able to cross. Sites are provisioned by
an operator, with `resources/database/seeds/NewSite.cfm`.

It lives outside the webroot on purpose. Copy it in, run it from the server
itself, delete it:

```bash
cp resources/database/seeds/NewSite.cfm public/__newsite.cfm
```

```bash
curl -G "http://127.0.0.1/__newsite.cfm" \
     --data-urlencode "name=Acme Legal" \
     --data-urlencode "domains=acme.example.com,www.acme.example.com" \
     --data-urlencode "owner=jane@acme.example.com" \
     --data-urlencode "ownerName=Jane Smith" \
     --data-urlencode "theme=default"
```

```bash
rm public/__newsite.cfm
```

`-G --data-urlencode` matters: the values contain spaces and commas.

The script refuses any connection that is not local, because a provisioning
endpoint reachable from the internet creates tenants and accounts for whoever
finds it. Deleting the file afterwards is the real control; the guard is there
for the window before you do.

It prints a generated owner password once. That is the only time it is
readable — it is stored hashed.

### What it creates

| | |
|---|---|
| Site | name, slug, timezone, locale |
| Domains | first is primary, rest are aliases |
| Theme | a directory under `/themes` |
| Roles | the default set, scoped to this site |
| Owner | a user with the `owner` role and a generated password |
| Home page | published, and wired to `pages.homePageId` |
| Menu | `primary`, with one item pointing at Home |
| Contact form | at `/contact`, delivering to the owner |
| Settings | `seo.indexable`, `seo.baseUrl`, `site.title` |

Everything there is editable in the admin afterwards. The list exists because
those are the pieces that are irritating to add by hand, not because they are
fixed.

Nothing is deleted. If the slug or a domain is already taken, the service
throws and the script stops without touching what exists.

## Adding a site manually

The script is a convenience, not a requirement — it calls the same public
services you can call yourself. Do it by hand when you want a different shape:
no contact form, no starter page, an existing user, or a tenant added to a
running system without copying anything into the webroot.

There are two honest routes. Which one you want depends on whether you need a
user created along with the site.

### Route A — the services, from a scratch template

The recommended manual route. It goes through the same validation, slug
derivation and password hashing as everything else, so nothing lands in a state
the application would not have produced itself.

```cfml
<cfscript>
wb       = application.wirebox;
sites    = wb.getInstance( "SiteService@core" );
roles    = wb.getInstance( "RoleService@core" );
users    = wb.getInstance( "UserService@core" );
pages    = wb.getInstance( "PageService@pages" );
themes   = wb.getInstance( "ThemeService@core" );
settings = wb.getInstance( "SiteSettingsRepository@core" );

site = sites.createSite(
    name     = "Acme Legal",
    timezone = "Australia/Sydney",
    locale   = "en_AU"
);

sites.addDomain( site.getId(), "acme.example.com", true );
sites.addDomain( site.getId(), "www.acme.example.com", false );

themes.setThemeForSite( site.getId(), "default" );

roles.seedDefaultRolesForSite( site.getId() );

owner = users.createUser( site.getId(), "Jane Smith", "jane@acme.example.com", "<a strong password>" );
users.assignRole( owner.getId(), roles.getRoleBySlugForSite( "owner", site.getId() ).getId() );

home = pages.createPage(
    siteId   = site.getId(),
    title    = "Home",
    slug     = "home",
    authorId = owner.getId()
);

pages.publishPage( home.getId(), owner.getId() );
settings.put( site.getId(), "pages.homePageId", home.getId() );
</cfscript>
```

Order matters in two places. `seedDefaultRolesForSite()` has to run before you
assign a role, and the home page needs an author, so the owner comes first.

Drop it in the webroot, request it once over `127.0.0.1`, delete it. Same
handling as the provisioning script, for the same reason.

### Route B — SQL for the tenant, the admin for the rest

The three tenancy tables are plain enough to write by hand, and this is the
route that does not require putting an executable file in the webroot.

```sql
INSERT INTO sites (name, slug, status, timezone, locale, created_at, updated_at)
VALUES ('Acme Legal', 'acme-legal', 'active', 'Australia/Sydney', 'en_AU', NOW(), NOW());

SET @site := LAST_INSERT_ID();

INSERT INTO site_domains (site_id, domain, is_primary, is_active, created_at, updated_at)
VALUES (@site, 'acme.example.com',     1, 1, NOW(), NOW()),
       (@site, 'www.acme.example.com', 0, 1, NOW(), NOW());

INSERT INTO site_settings (site_id, setting_key, setting_value, created_at, updated_at)
VALUES (@site, 'theme',          'default',    NOW(), NOW()),
       (@site, 'seo.indexable',  'true',       NOW(), NOW()),
       (@site, 'site.title',     'Acme Legal', NOW(), NOW());
```

Three things to get right:

- **`created_at` and `updated_at` are `NOT NULL` with no default.** Every insert
  has to supply them.
- **Store the hostname exactly as `DomainNormalizer` would:** lowercased, no
  scheme, no port, no trailing dot. A row that differs by so much as a capital
  letter never matches an incoming request, and the failure looks like a 404
  rather than a bad row. `www.` is *not* stripped — that is a separate row, on
  purpose.
- **Only one row per site may have `is_primary = 1`.** A functional unique index
  enforces it, so a second one is rejected rather than silently accepted.

That gives you a resolvable tenant with a theme. It has no users, so signing in
at its hostname is not yet possible — which is what the next part is for.

### Signing in to a site that has no users

A platform super admin is a user with `site_id IS NULL`. They reach every
tenant, so they can sign in at the new site's own hostname and create its roles
and users through the admin.

If you do not have one — the Will Creator provisioning deliberately removed the
seeded `root@platform.test` — create one through the service, not by hand:

```cfml
users.createSuperAdmin( "Platform Admin", "ops@yourcompany.com", "<a strong password>" );
```

Then open `http://acme.example.com/admin`, sign in, and use **Roles** and
**Users** to give the client their own accounts. Keep the super admin for
operations; it is not a client login.

### What you cannot do in SQL

Three columns are computed by the application, and a hand-written row will be
wrong in ways that surface much later:

- **`users.password_hash` is BCrypt.** There is no plaintext to insert and no
  MySQL function that produces the right value. Users go through
  `UserService`, or through the admin.
- **`pages.path` is a materialised full path** (`"services/wills"`), unique per
  site, and it has to agree with the parent chain. `PageService` builds it and
  rewrites descendants on a rename or move. Writing one by hand produces a page
  that resolves inconsistently or collides on the unique index.
- **Permissions are resolved from the catalogue at seed time.** The owner role
  grants everything by looking up every registered permission, so a role
  assembled by hand stops being complete the moment a module registers a new
  capability. Use `seedDefaultRolesForSite()`, which is idempotent and is also
  how an *existing* site picks up permissions from a newly installed module.

### One gap worth knowing

`pages.homePageId` has no field in the admin. Until it is set, the site's root
URL has no page to resolve and returns 404 even though the site is otherwise
working. Both routes above set it; if you skip that step, set it directly:

```sql
INSERT INTO site_settings (site_id, setting_key, setting_value, created_at, updated_at)
VALUES (<site id>, 'pages.homePageId', '<page id>', NOW(), NOW())
ON DUPLICATE KEY UPDATE setting_value = VALUES(setting_value), updated_at = NOW();
```

An upsert rather than an `UPDATE`, because the row does not exist until
something writes it — a plain `UPDATE` would report success having changed
nothing.

## Themes

A theme is a directory under `/themes`, deployed with the application; the
selection is per-site data. Two sites can share one theme, or each have their
own.

To give the new site its own look, copy an existing theme and edit it:

```bash
cp -R themes/default themes/acme
```

Then set `name` in `themes/acme/theme.json` and pass `theme=acme` when
provisioning. `ThemeService` falls back to the default theme — loudly, in the
log — if a site names one that is not installed, so a bad deploy renders plainly
instead of taking the site offline.

Static assets do *not* go in that directory. CSS, JS and fonts belong under
`public/assets/themes/acme/`, and the site's logo belongs in its media library —
see [theme-assets-and-branding.md](theme-assets-and-branding.md) for the split
and the reason for it.

## Outside the application

Two things the CMS cannot do for you:

1. **DNS** — point the hostname at the server.
2. **Apache** — the vhost has to accept that hostname. Add it as a
   `ServerAlias` on the existing vhost rather than writing a second one: the
   application is the same, only the `Host` header differs, and a second vhost
   means a second copy of the rewrite rules to keep in sync. See
   [deployment/apache-modjk.md](../deployment/apache-modjk.md) for why those
   rules cannot live in `.htaccess`.

TLS is per-hostname. A new domain needs its own certificate coverage — with
certbot, re-run it including every hostname the vhost now answers for.

## Verifying

```bash
curl -s -o /dev/null -w "%{http_code}\n" -H "Host: acme.example.com" http://127.0.0.1/
```

A `200` means DNS and TLS are the only things left. A `404` means the hostname
never resolved to a tenant — check `site_domains`, and check that Apache is
passing the `Host` header through unchanged.
