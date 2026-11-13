# AGENTS.md

Instructions for AI coding agents working in this repository. Written for an
agent that has not seen this codebase before.

If you read nothing else, read **[Traps](#traps)** — every entry there is
something that already cost a debugging session here.

## What this is

A multi-tenant CMS: one application and one MySQL database serving many client
websites. ColdBox 8 (HMVC) on Adobe ColdFusion, CommandBox locally.

A request's tenant is resolved from its `Host` header once per request and read
from `TenantContext` everywhere else.

## Commands

```bash
box install                 # dependencies; writes .env from .env.example
box migrate up              # apply migrations
box server start            # start the server (port is assigned, not fixed)
box server info             # what port
box run-script format       # format app/ and tests/
```

Tests run over HTTP, not from the CLI:

```
/tests/runner.cfm                                              # everything
/tests/runner.cfm?reporter=text&bundles=tests.specs.unit.X     # one bundle
```

**`box migrate status` is broken** — a bug in the `commandbox-migrations`
module, not in this project. `migrate up` works.

## Non-negotiables

**Work is delivered in numbered Groups, reviewed one at a time.** Implement only
the group or item that was asked for. When something outside it looks necessary,
say so and leave it — do not build ahead. Speculative code has to be unpicked.

**Do not copy from `myCFCMS_bk`** or any backup directory, if one is present.
Write the code.

**Business logic lives in services.** Handlers read the request, call a service,
and render. A service renders nothing and knows nothing about HTTP. This is what
lets the admin screens and the REST API share one implementation of "create a
page" — and why an API endpoint cannot drift from the screen it mirrors.

```
Request -> Handler -> Service -> Repository -> Database
```

**Core never depends on a feature module.** `app/modules/core` holds
infrastructure; feature modules depend on it and it never depends on them. The
dependency arrow points inwards, always.

Where Core genuinely needs something a module owns, it goes through a
**registry** that the module registers with in its own `onLoad`:
`ContentResolverRegistry`, `SiteNavigationRegistry`, `SitemapRegistry`,
`LinkTargetRegistry`, `ShortcodeRegistry`, `AdminNavigationRegistry`,
`ApiRouteRegistry`, `SeoCheckRegistry`, `SeoCrawlCheckRegistry`. Installing or
removing a module adds or removes its contribution with no change to Core.

**Permissions fail closed.** Both request boundaries refuse an action with no
declared permission. Forgetting to declare one must never read as "public".

## Two request boundaries, deliberately siblings

Not a base class and a subclass. They share a shape and almost nothing else.

| | `SecuredHandler` | `ApiHandler` |
| --- | --- | --- |
| Credential | Session cookie | Bearer token |
| CSRF | Required | None needed — nothing is sent automatically |
| Renders | A layout | JSON |
| Refuses by | Redirecting to sign-in | A status code |

Both declare `variables.permissions = { action : "slug", "$every" : "slug" }`
and both fail closed.

API authentication is **tokens only — there is no cbSecurity and no JWT**. The
`JWT_SECRET` in `.env.example` is dead scaffold; ignore it. Tokens are 32 random
bytes, hex, `cms_`-prefixed, stored **hashed**, and bound to one site.

Every API response is `{"data":…,"meta":…}` or
`{"error":{"code":…,"message":…}}`. Every API write calls `recordChange()`,
which logs a before/after snapshot to `api_change_log`.

## Testing

- Integration specs write real rows. **Migrations must have run.**
- Throwaway fixtures are prefixed **`zzt-`** and torn down with
  `DELETE FROM sites WHERE slug LIKE 'zzt-...%'` — the cascade from `sites` is
  what makes teardown reliable. Follow the convention.
- Assert on what must **not** be reported, not only on what must. A check or a
  validator that fires when the input is fine is worse than one that misses
  something, because the output gets ignored.
- Some specs make real HTTP requests back to the running server — media uploads
  (`fileUpload()` needs a genuine multipart request) and SEO audits (a status
  code is a finding). They read `cgi.server_port` and **skip** when the suite
  was not reached over HTTP, so a green run proves nothing about those paths in
  an environment that cannot reach itself.
- When a spec fails because a fixture is unrealistic, fix the fixture, not the
  assertion.

## Traps

**After changing a singleton or a `ModuleConfig.cfc`, reinitialise:**
`/healthcheck?fwreinit=1`. Services are WireBox singletons and the API route
table is built once at framework load. Skip this and correct code behaves like
the old code — the most expensive failure mode here, because nothing errors.

**The elvis operator falls through on any falsy value, not just null.**
`rc.flag ?: true` returns `true` when `rc.flag` is `false`. For a boolean or a
date, test `structKeyExists()` / `isNull()` separately. This has caused real
bugs more than once.

**`isNull()` on a missing struct key raises on Adobe** rather than answering
true. Use `structKeyExists()`.

**A missing struct key raises on a bracket lookup** too — `s[ k ] ?: x` does not
save you. `structKeyExists()` first.

**You cannot mix positional and named arguments** in one call. ACF rejects it
outright. This bites in TestBox: `it( "title", function(){}, skip = x )` will
not compile — name all four.

**A local variable cannot reuse an argument's name.** `var total = ...` inside a
function with a `total` argument is rejected.

**Arrays are passed by value; structs by reference.** A private method that
appends to `arguments.someArray` appends to a copy. Return the array and have
the caller reassign it. This silently broke the SEO crawl queue once, and the
struct beside it worked perfectly, which made it harder to see.

**Unqualified BIF names win over your own methods.** A method named `isImage()`
called unqualified from inside its own component resolves to the ColdFusion
built-in, which then fails validation and takes the component out of WireBox
entirely.

**ACF rejects a member call chained off a parenthesised elvis expression.**
`( a.b ?: [] ).map( ... )` will not compile. Assign first.

**A multipart request body is a byte array on ACF.** `trim()` on one throws.

**`reFind( ..., returnSubExpressions = true )` returns `len` and `pos` as
arrays**, not numbers. `code.len` used as a boolean throws.

**`cgi` is empty inside `cfthread`.** Anything derived from the request — the
host, the port, the scheme — must be resolved on the request thread and passed
in.

**qb binds an empty string as NULL.** For an empty `path`, which is a real
value here (the home page), bind explicitly with `null : false`.

**Migrations have no application context.** A migration cannot reach WireBox or
any service; it is raw SQL. Where that forces a definition to be duplicated, add
a spec asserting the copies agree.

## Comments

Match the surrounding density, which is high — but only for the **why** the code
cannot show: a trade-off, a rejected alternative, a bug this shape prevents.
Never narrate what the next line does. If a comment would only restate the code,
leave it out.

## Where to look

`readme.md` indexes everything. In short:

| | |
| --- | --- |
| `docs/architecture/` | One file per subsystem: what is implemented, and what is deliberately postponed and why |
| `docs/guides/running-locally.md` | Local setup, tests, reinit, common problems |
| `docs/deployment/` | Deploying, and the Apache/mod_jk hand-off |
| `app/modules/core/` | Tenancy, auth, authorization, routing, themes, SEO, the API boundary |
| `app/modules/<feature>/` | One feature each; `pages` is the template the rest follow |
| `resources/database/migrations/` | Schema history, in timestamp order |

Read the architecture file for a subsystem before changing it. They record
decisions and the alternatives already rejected, which is usually the question
you were about to ask.
