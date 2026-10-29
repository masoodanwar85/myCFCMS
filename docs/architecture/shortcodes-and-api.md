# Shortcodes and the REST API

The last two Core areas from the original plan. Different problems, one shared
idea: **a module contributes a capability, and Core never learns what it is.**

---

## 1. Shortcodes

`[recent-posts count="3"]` in a page's content becomes a list of blog posts,
without the Pages module — or Core — knowing the Blog module exists.

### Sanitise on save, expand on render

The order is the whole design:

```
author types  ->  AntiSamy sanitises  ->  stored as "[recent-posts count=3]"
                                            |
                          render  ->  expanded to <ul>…</ul>
```

- A shortcode is **plain text**, so it survives the sanitiser untouched. Storing
  expanded HTML instead would mean the AntiSamy policy had to permit whatever
  any shortcode might emit — the opposite of the point.
- Because expansion runs *after* sanitising, **handler output is never
  sanitised**. That is correct — it is application code, not author input — and
  it is the sharp edge. A handler that interpolates an attribute into its output
  without escaping has created stored XSS on every page using the shortcode.
  Every handler is given an `escape` callback in its context, and the shipped
  handlers have specs that try to break them.

Expansion happens in each module's **content resolver**, not in the theme, so a
third-party theme does not have to know shortcodes exist. The entity is rebuilt
from a row on every request, so setting expanded content on it changes nothing
in the database.

### The parser is a scanner, not a regex

The pattern this needs — a tag, an arbitrary attribute list, an optional body
ending in a *matching* close tag — wants backreferences and lazy groups. This
project has twice been bitten by assumptions about which regex engine
ColdFusion is using, so it is a hand-written scanner instead: longer, and it
does exactly what it says.

Most of its specs are about what is **not** a shortcode. Content is full of
square brackets:

| Input | Read as |
| --- | --- |
| `[year]` | a shortcode |
| `[1]`, `[2]` | prose — a tag must start with a letter |
| `[see fig. 2]`, `[ibid., p. 4]` | prose |
| `[image id="12` | prose — an unterminated quote must not swallow the document |
| `[[year]]` | the literal text `[year]` |

### The sanitiser gets there first

Content reaches the parser **after** AntiSamy has run, and AntiSamy encodes
quote characters in text. So what an author typed in the editor as:

```
[recent-posts count="3"]
```

is stored, and parsed, as:

```
[recent-posts count=&quot;3&quot;]
```

Read naively that is an *unquoted* value of `&quot;3&quot;` — not a number — so
every shortcode attribute written through the editor silently fell back to its
default. `count="3"` rendered one post. The parser therefore treats an
entity-encoded quote as a quote, and decodes entities inside a value before
handing it to a handler.

This is the normal case, not an edge one: it is what *every* editor-authored
shortcode looks like by the time anything reads it.

### Three rules that are decisions, not accidents

**One pass.** A handler's output is not re-scanned. A shortcode emitting another
shortcode could otherwise loop forever on a page any author is free to write,
and "what does this expand to" would stop being answerable by reading one
handler.

**Unknown tags are left alone.** An unrecognised `[gallery]` is put back exactly
as written. Deleting it would make a typo indistinguishable from a shortcode
that worked, and would quietly erase content when a module is uninstalled. The
cost is that an author sees their mistake on the page — which is the point.
`findUnknownTags()` exists so an admin screen can warn instead.

**A broken shortcode costs its own output, not the page.** A handler that throws
is logged, and its original text goes back so the author can see which one
failed.

### What ships

| Tag | Owner |
| --- | --- |
| `[year]`, `[site-name]`, `[site-url]` | Core |
| `[image id="12" align="right"]Caption[/image]` | Media |
| `[file id="12"]Optional label[/file]` | Media |
| `[recent-posts count="3"]` | Blog |

Two modules claiming one tag throws at registration rather than
last-registration-wins — otherwise whichever module loaded second would silently
change what an existing page renders.

---

## 2. The REST API

### Tokens, not sessions

A session cookie is right for a browser and wrong for an API: it is sent
automatically, which is what makes CSRF possible, and there is nowhere for a
script or another server to keep one. A token is presented deliberately on every
request — which is also why the API needs no CSRF protection at all.

**Only a hash is stored.** SHA-256, and the plain token exists only on the object
returned by `issue()`. "Show it once" is a property of the design, not a rule the
admin screen has to remember.

SHA-256 rather than BCrypt, deliberately, and it is the opposite trade to
passwords:

| | Password | API token |
| --- | --- | --- |
| Source | short, human-chosen | 32 bytes of `SecureRandom` |
| Attackable by dictionary | yes | no |
| Verified | once per sign-in | every request |
| Hash | BCrypt, deliberately slow | SHA-256, fast |

A slow hash on every API request is a self-inflicted denial of service; a fast
hash on a human password is negligence. Both are right in their place.

The token is `cms_` + 64 hex characters. The fixed prefix is what secret
scanners key off — a token that can be spotted in a public repository is one
that can be revoked before it is used. Generated with `java.security.SecureRandom`,
**not `createUUID()`**: a UUID looks random and is not required to be
unpredictable.

### Authorisation is the admin's, not a parallel set

An API request is authorised against `pages.view`, not `api.pages.read`. A
second permission set is how an installation ends up with an API that can do
things the admin refuses, and nobody notices until it is used. There is a spec
that fails if any API handler declares a permission beginning `api.`.

A token can never do more than the user it was issued to. Revoking their access
revokes the token's with it, and a token is bound to one site — presenting a
perfectly good token against another tenant's domain is a `403`.

Every reason a token is unusable — unknown, revoked, expired, user deactivated,
site suspended — returns the **same** message. A client that can tell them apart
can enumerate them.

### One envelope

```json
{ "data": …, "meta": { … } }
{ "error": { "code": "forbidden", "message": "…" } }
```

Collections are wrapped so that adding pagination later does not change the
shape. Errors are one shape so a client can handle them generically.
`failFromException` maps a service's typed error onto a status code — a
`…NotFound` is a 404, a `…HasChildren` or `…AlreadyExists` is a 409, an
`Invalid…` is a 422 — so every handler does not repeat the same `switch`. An
unrecognised exception is a 500 and its **message is not passed on**: that text
is written for a log and may name a table, a path or a query.

### Modules declare resources; Core builds the routes

A module cannot add `/api/v1/pages` to its own `routes` array — module routes
are relative to the module's entry point, and Pages lives at `admin/pages`. Nor
can it push a route onto the application router in `onLoad`: that appends
*below* the public catch-all, where nothing will ever reach it.

So a module declares a resource:

```cfc
wirebox.getInstance( "ApiRouteRegistry@core" )
       .resource( name = "pages", module = "pages", memberActions = "publish,unpublish" );
```

and Core builds the conventional set, inserting it above the catch-all once
every module has loaded. The conventions are Core's so that two modules cannot
disagree about what a collection URL looks like — the sort of inconsistency an
API is judged on and can never fix afterwards.

Member actions are **named explicitly** rather than routed from a `:action`
placeholder. A placeholder would let a caller name any public method on the
handler and have the framework invoke it, including inherited ones — a routing
convenience that is really a way to reach code nobody meant to expose.

**Collection actions** are the same idea for the things that act on the resource
rather than on one of its members, and become `POST /api/v1/<name>/<action>`:

```cfc
.resource( name = "seo-audits", module = "seoaudit", collectionActions = "page" )
```

Both kinds are declared **above** `/:id`, or `/seo-audits/page` is read as a run
whose id is `page`.

### What a page resource accepts

`title`, `slug`, `content`, `metaTitle`, `metaDescription`, `sortOrder` and
`parentId` are named arguments. Everything else a page has — `canonicalUrl`,
`robotsIndex`, `robotsFollow`, the `og*` fields, `twitterCard`, the `sitemap*`
hints, `template`, `featuredImage`, `inheritFeaturedImage`, `showHeading`,
`publishFrom`, `publishUntil` — travels in one `seo` struct, which is how
`PageService` already takes them from the admin screen.

Values are passed through **verbatim**. The service converts and validates each
one (`asBoolean` for switches, a clamp for `sitemapPriority`, `fromList` for the
enums, `safeUrl` for addresses), so a handler coercing them first would be a
second opinion on the same question and the two would eventually disagree.

`headMarkup`, `bodyMarkup` and `jsonLd` are only read from the request when the
token's user holds `content.unfiltered`. The service refuses them too — this is
the outer of two gates, so a crafted request cannot reach the service with
values it will silently drop.

The admin's equivalent needs `seoTabPresent` and `contentTabPresent` markers
because an unticked HTML checkbox posts nothing at all, so absence there cannot
be told from "off". JSON has no such problem: `false` arrives as `false`, and a
missing key is genuinely missing. That is what makes this a PATCH — and why a
request that says nothing about `parentId` leaves the page where it is, rather
than promoting it to the top level.

Moving is a second call to `movePage`, made only when the parent actually
changed: it rewrites the path of every descendant and leaves redirects behind,
which is far too expensive to do because a client sent the whole object back.

The single-page projection carries all of these; the collection does not. Twenty
extra fields per row on a fifty-page tree is a response nobody asked for.

### What the other two resources serve

`GET /api/v1/themes` and `/api/v1/themes/:slug` are **read-only, permanently**.
A theme is a directory of `.cfm` templates deployed with the application, so
"create a theme" is a deploy and not an API call; the one part that *is* tenant
data — which theme a site renders through — is a site setting and belongs with
the rest of the site's configuration. The id in the URL is the slug, because a
theme has no numeric key and a surrogate one would be unguessable from a deploy.

Each theme carries a `templates` array, and that array is the point of the
resource: `page.template` names a file under the theme's `templates/` directory,
it is what `PATCH /api/v1/pages/:id { "template" : "..." }` sets, and nothing
else in the API says what the valid names are. The theme's `views/` are not
offered — Core asks a theme for `page` and `404` by name and a page cannot opt
into one. `active` is asked of `ThemeService` rather than read from the setting,
so a site pointed at a theme that is no longer deployed reports the fallback it
will actually render with.

`/api/v1/media` is `index`, `show` and `create` only.

Upload is a **`multipart/form-data` POST** with the file in a part named `file`,
because that is what `MediaService.upload()` takes: it hands the part to
`fileUpload()`, which lands it in staging before anything looks at it, and every
defence the service has — the extension allow-list, the per-kind size cap, the
magic-byte check, naming the file ourselves — is downstream of that. A base64
field in a JSON body would have been a second way into the library with its own
copy of those checks, which is the shape that eventually disagrees with itself.
`altText` and `title` travel as ordinary form fields beside it, and are worth
sending: alt text is the only thing that stops the SEO audit reporting the image,
and there is no second call that can add it.

The upload refusals are mapped in the handler rather than by
`failFromException`. Core maps types by the *shape* of the name — `...NotFound`
is a 404 — and `Media.NoFile`, `Media.TypeNotAllowed`, `Media.TooLarge` and
`Media.ContentMismatch` match none of those shapes, so every one of them would
have answered `500` with the message withheld. Each is the client's fault, each
has a status that says so (400, 415, 413, 422), and each message is already
written to be read by whoever tried.

No `PATCH` and no `DELETE`, deliberately. Editing a file's details needs
`media.update` and deleting needs `media.delete`; the `agent` role carries
neither, so both would be surface the only client we have cannot reach — and an
endpoint no token can use is a loose end, not a safeguard.

`/api/v1/seo-audits` is `index`, `show`, `create` and one collection action.

Starting a run answers **202, not 200**, because the response describes something
that has *begun*: the crawl is on a background thread, and the client polls
`GET /api/v1/seo-audits/:id` until `status` stops being `running`. A client that
read 200 as "the findings are in this response" would otherwise read an empty
report as a clean site. While a run is `running` the findings are deliberately
empty rather than partial — a run writes them in one statement at the end, and a
half-written report would be read as a verdict.

`SeoAudit.AlreadyRunning` is mapped to **409** in the handler. `failFromException`
classifies by the shape of a type name and would call it a 500; it is a conflict
with the state of the data, and the message says what to do about it.

`POST /api/v1/seo-audits/page` is the one-URL audit: no row, no thread, blocks
until it has an answer. A URL that does not answer comes back as a *finding* with
`statusCode: 404`, not as a 404 from the endpoint — otherwise a client could not
tell "no such page" from "no such endpoint". See `seo-audit.md` for what it does
and does not run.

### Every write is logged

A handler that changes something calls `recordChange()` on `ApiHandler`, which
writes a row to `api_change_log` with a `before` and an `after` snapshot. That is
the other half of letting a token write content: the `agent` role exists so an
automated client can, and this is how anybody finds out afterwards what it did.
It is read at `/admin/api-activity`.

The snapshots are the handler's **own public projection** — the same JSON the API
answered with — so the log records what the client saw rather than a second,
parallel description of a page that would drift from the first. `before` is taken
in the handler before anything is written, because that is the only moment the
previous state still exists, and as the projection rather than the entity:
entities are mutable and `updatePage` is handed the same instance, so a reference
kept would quietly become the *new* state.

Publishing is its own `action`, not an `update`, because "who published this" is
the question asked of the log most often and answering it should not mean diffing
two snapshots to spot a `status` field. A delete keeps only its `before`, and
that entry is the only record left of what the page said.

**A failed log never fails the request.** By the time the entry is written the
page already exists; refusing the response would tell the client the change did
not happen when it did, and a client that retried would create it twice. So the
service catches everything and reports it to the application log.

Reads are not recorded. A log of every `GET` would be an access log — useful,
much larger, a different thing — and it would bury the handful of entries that
say somebody changed something. Neither are changes made through the admin
screens: those carry a session rather than a token, and the screens already
attribute content to its author and editor.

### Reading the request body

Two things ColdFusion will not do:

1. **JSON.** A REST client sends `application/json`; ColdFusion leaves it as a
   string.
2. **PUT and PATCH.** ColdFusion populates the FORM scope for `POST` only. A
   form-encoded `PATCH` therefore arrives with an empty `rc` — and an update
   silently changes nothing while answering `200`, which is exactly what it did
   before this was written.

`ApiHandler` parses both, and values already in `rc` win, so a path parameter
like `:id` cannot be overwritten by a body claiming a different one.

### Three ColdFusion traps worth recording

**Read headers through the event.** `getHTTPRequestData()` reads the *real* HTTP
request — right in production, useless anywhere the framework drives the request
itself. Every authenticated spec failed with a 401 while the code was correct.
`event.getHTTPHeader()` works in both.

**And guard its result for null.** On ACF an absent header can come back as null
*despite* a supplied default — ColdBox's own source carries a comment about
exactly that. Without the guard, every unauthenticated request died with
"variable HEADER is undefined" instead of answering `401`. It failed closed, but
for the wrong reason and with the wrong status.

**A multipart body is a byte array.** `getHTTPContent()` returns bytes for a
`multipart/form-data` request on ACF, and `trim()` on a byte array throws — so
`readBody` killed every multipart request at the boundary, whatever endpoint it
was aimed at, which is why the media upload could not have worked before this
was found. The guard is `isSimpleValue`, and the body is then left alone:
ColdFusion has already unpacked the parts into FORM and the file itself is read
by `fileUpload()`.

---

## 3. What is intentionally postponed

| Area | Why it waits |
| --- | --- |
| Rate limiting | Belongs with a store that survives a restart, alongside the same gap on sign-in |
| `405 Method Not Allowed` | An unsupported verb on a known route currently 500s. ColdBox has a hook for this; it has not been wired |
| Blog resource | The seam is proven with Pages, Themes, Media and SEO audits; it is a handler and one line of registration |
| Media `PATCH` and `DELETE` | `media.update` and `media.delete` are withheld from the `agent` role, so neither has a caller |
| Scoped tokens | A token carries its user's full permissions. Narrower scopes need a UI for choosing them |
| Webhooks, GraphQL | The service layer is ready for both; neither has a caller yet |
| Change log retention | `api_change_log` grows without bound. There is no scheduler to prune it from |
| Logging a change in the same transaction as the change | Services do not expose transactions to handlers. A crash between the two loses the entry and keeps the change |
| Shortcodes in titles and excerpts | Expansion is scoped to content on purpose — a shortcode in a `<title>` has nowhere sensible to render |
| Nested shortcodes | Single-pass by design. A handler that wants to expand its own body can call the service |
