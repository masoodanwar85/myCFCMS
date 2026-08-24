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

### Two ColdFusion traps worth recording

**Read headers through the event.** `getHTTPRequestData()` reads the *real* HTTP
request — right in production, useless anywhere the framework drives the request
itself. Every authenticated spec failed with a 401 while the code was correct.
`event.getHTTPHeader()` works in both.

**And guard its result for null.** On ACF an absent header can come back as null
*despite* a supplied default — ColdBox's own source carries a comment about
exactly that. Without the guard, every unauthenticated request died with
"variable HEADER is undefined" instead of answering `401`. It failed closed, but
for the wrong reason and with the wrong status.

---

## 3. What is intentionally postponed

| Area | Why it waits |
| --- | --- |
| Rate limiting | Belongs with a store that survives a restart, alongside the same gap on sign-in |
| `405 Method Not Allowed` | An unsupported verb on a known route currently 500s. ColdBox has a hook for this; it has not been wired |
| Blog and Media resources | The seam is proven with Pages; each is a handler and one line of registration |
| Scoped tokens | A token carries its user's full permissions. Narrower scopes need a UI for choosing them |
| Webhooks, GraphQL | The service layer is ready for both; neither has a caller yet |
| Shortcodes in titles and excerpts | Expansion is scoped to content on purpose — a shortcode in a `<title>` has nowhere sensible to render |
| Nested shortcodes | Single-pass by design. A handler that wants to expand its own body can call the service |
