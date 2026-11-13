# Running myCFCMS locally

CommandBox is the only supported local setup. It downloads the CFML engine, runs
an embedded web server with URL rewriting, loads `.env` into the JVM, and gives
you the migration runner — four things a hand-installed ColdFusion does not do
for you.

## Prerequisites

| | Why |
| --- | --- |
| [CommandBox](https://www.ortussolutions.com/products/commandbox) 6+ | Runs the server, installs dependencies, runs migrations |
| MySQL 8 | The schema uses `utf8mb4`, generated-key reads and `FIELD()` ordering |
| Java 21 | `server.json` pins `openjdk21_jre`; CommandBox downloads it |
| Node 18+ | Only for the planned `/mcp` server. Not needed for the CMS |

Nothing needs a ColdFusion installation of your own. `server.json` declares
`adobe@2025`, and CommandBox fetches it on first start.

## First run

```bash
box install
```

`box install` writes `.env` from `.env.example` via the `postInstall` script, so
edit it afterwards rather than before:

```bash
# .env — at minimum
DB_DATABASE=mycfcms
DB_USER=root
DB_PASSWORD=your-password
```

Create the database, then build the schema:

```bash
mysql -u root -p -e "CREATE DATABASE mycfcms CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci"
box migrate up
box server start
```

`box server start` prints the port, which is assigned rather than fixed. Ask for
it again with:

```bash
box server info
```

## `.env` is a CommandBox thing, and only a CommandBox thing

This is the single most useful fact about configuration here, because it
explains a class of confusing behaviour.

ColdBox reads `ENVIRONMENT` through `getSystemSetting()`, which checks **JVM
system properties and OS environment variables — never the `.env` file**.
CommandBox is what loads `.env` into the JVM at `server start`. The `${DB_*}`
placeholders in `.cfconfig.json` are likewise resolved by CommandBox's
`cfconfig`, not by ColdFusion.

So: locally, `.env` works and configures the datasource for you. On a deployed
server there is no CommandBox, `.env` is inert, and the datasource is configured
in the ColdFusion or Lucee administrator instead. See
[../deployment/deploying.md](../deployment/deploying.md).

## You need a site before anything answers

The CMS is multi-tenant. Every public request is resolved from its `Host`
header to a row in `site_domains`, and a hostname with no matching row gets a
404 with no tenant — not an error, just nothing. A fresh database has no sites,
so a fresh install serves nothing at all. That is correct behaviour and it
catches everyone once.

`DomainNormalizer` strips the port before the lookup, so `127.0.0.1:58988`
resolves as `127.0.0.1`. Two ways to work with that:

- **Register `127.0.0.1` as a domain** on your development site. Simplest, and
  it means you can browse the port URL CommandBox gives you directly.
- **Use `/etc/hosts` entries** pointing a realistic hostname at loopback, e.g.
  `127.0.0.1 example.test`, and register `example.test`. Closer to production,
  and necessary if you want to exercise more than one tenant at once.

[adding-a-site.md](adding-a-site.md) walks through provisioning a site, its
domain and its first user.

## Migrations

```bash
box migrate up          # apply everything pending
box migrate down        # roll back the most recent
```

**`box migrate status` is broken** — it throws on
`nextMigration.keyExists("componentName")` inside
`commandbox-migrations/commands/migrate/status.cfc`. That is a bug in the
CommandBox module, not in this project, and `migrate up` is unaffected. To see
what has been applied, read the `cbmigrations` table.

Migrations run through CommandBox with **no application context**, so a
migration cannot reach WireBox or any service. Anything a migration needs to
know has to be written as raw SQL in the migration itself — which is why
`2026_10_29_100000_seed_agent_role.cfc` repeats the role definition that
`RoleService` also holds, with a spec asserting the two agree.

## Tests

Start the server, then open the runner on the reported port:

```
/tests/runner.cfm
```

One bundle at a time, which is what you want while working:

```
/tests/runner.cfm?reporter=text&bundles=tests.specs.integration.api.PagesApiSpec
```

Things worth knowing about this suite:

- **Integration specs need migrations to have run.** Most of them write real
  rows to the real database.
- **Throwaway fixtures are prefixed `zzt-`** and cleaned up with
  `DELETE FROM sites WHERE slug LIKE 'zzt-...%'`. Follow the convention: the
  cascade from `sites` is what makes teardown reliable.
- **Some specs make real HTTP requests back to the running server** — the media
  upload specs, because `fileUpload()` needs a genuine multipart request, and
  the SEO audit specs, because a status code is a finding. They read
  `cgi.server_port`, so they **skip rather than fail** when the suite was not
  reached over HTTP. A green run in an environment that cannot reach itself is
  not evidence those paths work.
- `/tests` is reachable because of the alias in `server.json`. It is not inside
  the webroot, and on a deployed server it should not be reachable at all.

## Reinitialising after a change

Most edits are picked up on the next request. These are not:

- a **singleton** model (`component singleton`) — the instance is cached
- a **ModuleConfig.cfc** — including registry registrations and API resources
- anything that changes the **routing table**, such as a new API resource

For those:

```
/healthcheck?fwreinit=1
```

`/healthcheck` rather than `/` because the root goes through tenant resolution
and the public catch-all. Forgetting this produces the most misleading symptom
in the project: correct code that behaves like the old code.

## Formatting

```bash
box run-script format
box run-script format:check
```

## Two local-only details in `server.json`

```json
"JVM": { "heapSize": "512", "args": "-Duser.timezone=UTC -agentlib:jdwp=...address=8888" }
```

- **A JDWP debug agent is enabled on port 8888.** Fine locally; it must never
  reach a server, where an open debug port is remote code execution.
- **512MB heap** is enough for development. An SEO audit of a large site holds
  one parsed DOM at a time by design, but give a production server more.

The `aliases` block makes `/tests` and `/coldbox/system/exceptions` web-reachable
for the runner and for the interactive error page. Both are CommandBox
conveniences and neither exists on a deployed server — which is why the
deployed error template deliberately has no external assets.

## Docker

`docker/Dockerfile` and `docker/docker-compose.yml` are the **unmodified ColdBox
scaffold**: they target the BoxLang image and a database called `coldbox`. They
are not wired to this project and are not a supported way to run it. Use
CommandBox, or fix them first.

## When something does not work

| Symptom | Cause |
| --- | --- |
| Every URL 404s with no error | No `site_domains` row matches your hostname |
| A code change has no effect | A singleton or ModuleConfig needs `?fwreinit=1` |
| `Datasource myCFCMS not found` | `.env` edited after `box server start`; restart the server |
| A new API route 404s | `ApiRouteRegistry` is read at framework load — `?fwreinit=1` |
| Upload or audit specs skipped | The suite was not reached over HTTP; open `/tests/runner.cfm` in a browser or curl it |
| `Access denied for user` on `box migrate up` | `DB_USER`/`DB_PASSWORD` in `.env`, not the MySQL client's own defaults |
