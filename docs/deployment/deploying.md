# Deploying myCFCMS

The deployed topology is **Apache → mod_jk → a CFML engine → MySQL**, with the
document root at `public/` and everything else outside it.

This file covers the whole procedure. Two things have their own pages because
they are long enough to deserve one:

- [apache-modjk.md](apache-modjk.md) — the vhost, and why the rewrite rules
  cannot live in `.htaccess`. Read it; the symptom of getting it wrong does not
  point at the cause.
- [../guides/running-locally.md](../guides/running-locally.md) — CommandBox.

**Engine support, stated plainly:** this application is developed and tested on
**Adobe ColdFusion** only. Lucee is plausible and has two known blockers that
must be fixed first — see [Lucee](#lucee) below. Nothing in this project has
ever run on Lucee.

---

## 1. What actually has to reach the server

```
app/            the application
lib/            framework and dependencies      <- NOT in git
public/         the document root
resources/      migrations and seeds
storage/        uploaded media                   <- NOT in git, and writable
themes/         layouts and views (outside the webroot, deliberately)
```

**`lib/**` is gitignored**, so a `git pull` on the server gives you an
application with no framework. Two options:

- **Install CommandBox on the server** and run `box install --production`. Also
  gives you the migration runner, which is the bigger win.
- **Ship `lib/` yourself** with `rsync`, built on a machine that has
  CommandBox.

Ship `lib/` or install it — do not try to run without it, and do not commit it.

`tests/` and `docs/` do not need to be deployed. `tests/` should not be
reachable over HTTP at all; it is only reachable locally because of an alias in
`server.json`, which has no equivalent on a real web server.

## 2. The document root is `public/`

Not the project root. This is a security requirement, not a preference: with the
project root served, `app/`, `resources/`, `tests/` and **`.cfconfig.json` —
which holds database credentials** — are all fetchable over HTTP.

Mappings need no administrator configuration. `public/Application.cfc` derives
`/app`, `/coldbox`, `/modules`, `/themes`, `/resources` and `/storage` from its
own location at runtime, so moving the project only means changing the vhost.

## 3. Database

Create the schema with `utf8mb4` / `utf8mb4_unicode_ci`:

```sql
CREATE DATABASE mycfcms CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
CREATE USER 'mycfcms'@'localhost' IDENTIFIED BY '...';
GRANT ALL PRIVILEGES ON mycfcms.* TO 'mycfcms'@'localhost';
```

The application uses a datasource named exactly **`myCFCMS`**, set as
`this.datasource` in `Application.cfc`. Create it in the engine's administrator
with that name.

### `.env` does nothing here

Worth being blunt about, because it is the most common wrong assumption.

ColdBox reads configuration through `getSystemSetting()`, which checks **JVM
system properties and OS environment variables — never the `.env` file**.
CommandBox is what loads `.env` into the JVM at `server start`, and the
`${DB_*}` placeholders in `.cfconfig.json` are resolved by CommandBox's
`cfconfig`. On a deployed engine neither exists.

So on the server:

- The datasource is configured **in the administrator**, not from `.env`.
- Leave `ENVIRONMENT` **unset**. It resolves to `production`, which is correct.
  Do not set it to `development` with a JVM argument: `development()` selects
  ColdBox's Whoops template, which loads CSS and JS from
  `/coldbox/system/exceptions/` — a path web-reachable only through the local
  `server.json` alias. On a real web server those 404 and you get an unusable
  shell instead of an error page.

## 4. Writable directories

The engine's service account (`cfusion`, `nobody`, `lucee`, depending on the
install) must be able to write:

| Path | What |
| --- | --- |
| `storage/media/` | Uploads, in per-site subdirectories |
| `storage/media/.staging/` | Where an upload lands before it is checked |
| `app/logs/` | LogBox |

```bash
chown -R cfusion:cfusion storage app/logs
chmod -R u+rwX storage app/logs
```

`storage/` is outside the webroot on purpose. Even a file that defeated every
upload check sits somewhere the web server will not execute, and `/media/...`
is served by a handler that scopes the file to the requesting tenant.

## 5. Theme assets go in the webroot; theme templates do not

`/themes` holds `.cfm` layouts and views and is **outside** the webroot. A
themes directory exposed to the web server would make `layouts/main.cfm`
directly requestable and, behind mod_jk, executable.

Static assets live at `public/assets/themes/<slug>/` instead, where Apache
serves them with no CFML request at all. `Theme.assetUrl()` builds those URLs.
Both halves have to be deployed.

## 6. Migrations

With CommandBox on the server:

```bash
box migrate up
```

### Without a migration runner

This is the case to plan for, because it is where mistakes happen. If the server
has no CommandBox, migrations must be applied by hand — and `box migrate up` on
a machine that can reach the production database remotely is a safer third
option than hand-written SQL whenever it is available.

Applying by hand means two things, and the second is the one people forget:

1. Run each migration's SQL **in filename order**. The filenames are
   timestamps and the order is a dependency order.
2. **Record each one in the `cbmigrations` table**, or a future
   `box migrate up` will try to run them all again:

```sql
INSERT INTO cbmigrations VALUES ( '2026_10_29_110000_create_api_change_log', NOW() );
```

That table has two columns — the migration's component name and when it ran —
and `name` is the filename without `.cfc`.

Migrations run with **no application context**: a migration cannot reach WireBox
or any service, which is why some of them repeat definitions that also live in
CFCs. Where that happens there is a spec asserting the two agree.

## 7. After every deploy: reinitialise

```bash
curl -s "https://example.com/healthcheck?fwreinit=1"
```

Not optional. Services are WireBox **singletons** and the API route table is
built once at framework load, so without this a deploy ships code that behaves
like the previous version. The symptom is correct code that appears not to work
— the most expensive failure mode in this project.

`/healthcheck` rather than `/`, because the root goes through tenant resolution
and the public catch-all.

## 8. Each site needs a primary domain

Not strictly a deploy step, but it is the first thing a real audit reports and
it breaks things quietly. Without a primary domain on a site:

- canonical URLs cannot be built,
- sitemap entries cannot be built,
- the SEO audit reports `site.noPrimaryDomain` as an error.

Set one per site under the site's domains.

---

## Adobe ColdFusion

The tested engine. Developed against **2025** locally, deployed on **2023**.

```
Ubuntu + Apache + mod_jk + ColdFusion 2023 + MySQL 8
```

1. Install ColdFusion and run its `wsconfig` tool to build the Apache
   connector.
2. Create the `myCFCMS` datasource in CF Administrator (*Data & Services →
   Data Sources*), MySQL driver, `utf8mb4`.
3. Set the document root to `public/` and add the vhost from
   [apache-modjk.md](apache-modjk.md).
4. `chown` the writable directories to the `cfusion` user.
5. Apply migrations, then `?fwreinit=1`.

### Two ColdFusion-specific notes

**`/*.cfm/*` must be mounted, not just `/*.cfm`.** `/index.cfm/about-us` does
not *end* in `.cfm`. ColdFusion's generated `uriworkermap.properties` already
has both.

**A connector rebuild overwrites `/opt/ColdFusion2023/config/wsconfig/<n>/`.**
Keep site-specific `JkMount` directives and all rewrite rules in your own
vhost so they survive re-running `wsconfig`.

### Settings worth checking in CF Administrator

| Setting | Why |
| --- | --- |
| Robust exception information | **Off.** The gated `/app/exceptions/BugReport.cfm` handles detail per viewer |
| Request timeout | The default 5 minutes is right; an SEO audit runs on a background thread, not the request |
| Enable debugging output | **Off** |
| JVM heap | 512MB is a local development figure. Give a server more |

Do **not** carry the local `server.json` JVM arguments to a server. They include
`-agentlib:jdwp=...address=8888`, an open Java debug port, which is remote code
execution.

---

## Lucee

**Unverified.** Nothing here has run on Lucee. The design is mostly
engine-neutral — ColdBox, qb, WireBox and BCrypt all run on both, and
`BaseRepository.generatedKey()` already reads both ACF's `generatedKey` and
Lucee's `generated_key` — but there are two blockers that will not announce
themselves.

### Blocker 1: `getSafeHTML()` does not exist on Lucee

`ContentSanitizer.sanitize()` calls `getSafeHTML( content, policyPath() )`,
Adobe's OWASP AntiSamy binding. Lucee has no such BIF.

What makes this dangerous is the fallback. The call is wrapped in a `try`, and
on failure it logs and returns `encodeForHTML( content )` — deliberately, so a
sanitiser failure renders markup as visible text rather than publishing
unvetted HTML. On Lucee that path would be taken for **every piece of content
on every page**, and the site would display literal `<p>` and `<h2>` tags
everywhere while the log filled with errors. It fails safe, and it fails
silently as far as a browser is concerned.

The fix is confined to one file, which is what that file was written for:
`ContentSanitizer` is the only place the engine-specific call appears. Add a
Lucee branch using Lucee's own sanitiser (the AntiSamy extension, or
`esapiSanitize()`), keeping `resources/security/antisamy-cms.xml` as the policy
if the chosen route accepts one. The project ships its own policy because
Adobe's bundled `antisamy-basic.xml` strips headings, tables, rules, underline
and strikethrough — everything the editor offers beyond bold and italic.

Verify with `ContentSanitizer`'s own specs before trusting it.

### Blocker 2: TagSoup is not on Lucee's classpath

`HtmlDocument` parses fetched pages with
`org.ccil.cowan.tagsoup.Parser`, chosen precisely because `tagsoup-1.2.jar`
already ships on **ColdFusion's** classpath — no dependency, nothing to deploy.
Lucee does not bundle it.

The failure is quiet in a different way: `loadHtml()` catches the exception,
records a parse error, and `isParsed()` returns false. Every URL in an SEO audit
then reports `status.unparseable` and no on-page check runs at all.

The fix is a file copy. `Application.cfc` already declares:

```cfc
this.javaSettings = { loadPaths : [ _libRoot ], ... }   // lib/java
```

so dropping `tagsoup-1.2.jar` into `lib/java/` puts it on the application's
classpath. `.gitignore` ignores `lib/**` but explicitly un-ignores `lib/java/`,
so the jar can be committed.

### Then verify these

Not known to be broken — known to be unverified, and each would be quiet:

| Area | What to check |
| --- | --- |
| `dateTimeFormat( value, "iso" )` | Used in 29 places, mostly in API projections and mementos. Confirm Lucee produces ISO 8601 for that mask rather than a literal or an error |
| Image handling | `MediaService` decodes every upload with `imageRead` and reads dimensions with `imageInfo`. Confirm the formats in `ALLOWED` — including **WebP** — actually decode |
| `cfhttp` `Host` override | `PageFetcher` replaces the `Host` header to reach the right tenant over loopback. Verified on the wire on ACF only; if Lucee *adds* a second header instead of replacing it, audits reach the wrong tenant |
| Multipart request bodies | `ApiHandler.readBody()` guards with `isSimpleValue` because ACF hands back a byte array. The guard is engine-neutral, but confirm uploads reach `fileUpload()` |
| The `/tests` mapping | `server.json`'s install script already creates a CFML mapping for `/tests` on Lucee that ACF does not need — evidence this was once considered. Not needed in production |

### Datasource

`.cfconfig.json` is already Lucee-shaped — `bundleName`, `bundleVersion` and
`class` are Lucee's OSGi driver keys, and `DB_BUNDLENAME=com.mysql.cj` is
meaningless to ACF. On Lucee you can configure the datasource through
`cfconfig` or in Lucee Admin; the name must be `myCFCMS` either way.

### mod_jk with Lucee

The reasoning in [apache-modjk.md](apache-modjk.md) is about mod_jk and
mod_rewrite phases, not about the engine, so it applies unchanged. The mounts
come from your own Tomcat worker rather than ColdFusion's generated
`uriworkermap.properties`, and `/*.cfm/*` still has to be mounted.

---

## Deploy checklist

```
[ ] lib/ present on the server (box install --production, or rsync)
[ ] DocumentRoot is public/
[ ] vhost rewrite rules at vhost level, not .htaccess
[ ] /*.cfm and /*.cfm/* mounted
[ ] datasource named myCFCMS exists in the administrator
[ ] storage/ and app/logs/ writable by the engine user
[ ] public/assets/themes/<slug>/ deployed alongside themes/
[ ] migrations applied AND recorded in cbmigrations
[ ] ENVIRONMENT unset; robust exceptions and debugging off
[ ] no JDWP debug agent in the JVM arguments
[ ] every site has a primary domain
[ ] ?fwreinit=1
[ ] tests/ not reachable over HTTP
```

## What this project does not have yet

| | |
| --- | --- |
| CI | No workflows in `.github/`. Tests are run by hand |
| A deploy script | No `rsync`/`git pull` automation is committed |
| Scheduled tasks | No scheduler, so nothing prunes `api_change_log` or runs nightly audits. `POST /api/v1/seo-audits` with a token makes the second a cron one-liner |
| A usable Docker setup | `docker/` is the unmodified ColdBox scaffold, targeting BoxLang and a database called `coldbox` |
