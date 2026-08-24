# SEO and menus

Two Core areas from the original plan, finished together because they share a
question: **what is this site's address, and what does it want people to reach?**

---

## 1. Why SEO needed a new idea: the absolute URL

Every public URL elsewhere in this CMS is a path. A path is what a browser
needs, and what a tenant-scoped router understands. A canonical tag, an Open
Graph tag and a sitemap entry are each read by something that is *not* on the
site, so each needs a scheme and a host.

In a multi-tenant CMS, "which host" is a real question. A site may answer on
`example.com`, `www.example.com`, `127.0.0.1` and a staging hostname. A
canonical URL that changes depending on which one a reader arrived through is
worse than no canonical URL at all — it is the exact duplicate-content problem
the tag exists to solve.

So `SeoService` builds addresses from the site's **primary domain**, never from
the request:

```
reach a page by four hostnames  ->  all four name one canonical address
```

The scheme is the one thing taken from the request, because it is the one thing
the database cannot know: the same site is `http` behind a developer's
CommandBox and `https` in production.

| Source | When |
| --- | --- |
| `seo.baseUrl` site setting | Always wins. Set it when a proxy terminates TLS and does not forward the scheme |
| `X-Forwarded-Proto` | A load balancer that does forward it |
| `cgi.https` | TLS terminated by ColdFusion itself |
| `http` | Otherwise, because that is what this request demonstrably is |

**A site with no primary domain gets no canonical tag at all.** An absent tag
costs a little; a tag pointing at nothing can de-index a site.

---

## 2. What a resolver may now say

`ContentResolverRegistry`'s contract grew six optional keys. All optional, so
adding them obliged no existing resolver to change:

```cfc
{
    canonicalPath : "about",      // the one URL this should be indexed at
    robots        : "noindex",    // per-page directive
    image         : "/media/...", // social preview
    contentType   : "article",    // Open Graph type
    publishedAt   : <date>,
    modifiedAt    : <date>
}
```

### The trap in `canonicalPath`

An empty `canonicalPath` is a **meaningful answer**: it names the site root. The
first version defaulted it downstream with `len( x ) ? x : requestedPath`, which
read "the site root" as "the resolver said nothing" — so `/home` canonicalised
to `/home`, and the home page was offered to search engines at two addresses.

It is now defaulted in `normalize()`, which knows the requested path, so an
empty string genuinely means the root everywhere downstream.

This is the same trap as `order ?: 100` turning a nav item's order of `0` into
`100`, and as the site-settings bug in §5. **ColdFusion's `?:` falls through on
any falsy value, not just null.** In a codebase where "", `0` and `"false"` are
all legitimate stored values, `?:` is a bug waiting for the right data.

### What each module claims

| URL | Canonical | Robots |
| --- | --- | --- |
| `/` and `/home` | `/` | — |
| `/about` | itself | — |
| `/blog/a-post` | itself, `og:type=article` | — |
| `/blog/page/2` | `/blog` | `noindex, follow` |
| `/blog/category/x` | itself | — |
| a 404 | **none** | `noindex, follow` |

Page 2 of an archive is a slice of a list, not a document: its content changes
as posts are added, and indexing it competes with the posts themselves.
*Followed*, so a crawler still walks through to every post.

---

## 3. `/sitemap.xml` and `/robots.txt`

Handlers, not files in `public/`, because both are **per tenant**. One static
`robots.txt` in the webroot would be shared by every site on the installation,
so a staging tenant could not be closed to crawlers without closing every
client's site with it.

> The scaffold's `public/robots.txt` was deleted for exactly that reason. A file
> in the webroot is served by the web server before any route is consulted, and
> would have silently shadowed the route.

`SitemapRegistry` is the fourth registry on the pattern Core already uses — a
module answers for its own content and Core learns nothing about it:

```cfc
array getSitemapEntries( numeric siteId )
    -> [ { path, lastModified, changeFrequency, priority } ]
```

Published content only. A draft in a sitemap invites a crawler to index a URL
that 404s. Blog categories are deliberately excluded: a category page is a
filtered view of posts already listed individually, and on a site with many
categories it would be most of the sitemap.

A provider that throws is skipped with a warning. A sitemap missing one module's
content is a smaller problem than a sitemap that 500s, which a crawler may retry
for days.

### Closing a site to search engines

One switch on Settings. It is deliberately belt-and-braces, because a crawler
may hold a URL it never re-fetches `robots.txt` for:

- `robots.txt` becomes `Disallow: /`
- every page gets `noindex, nofollow`
- `/sitemap.xml` returns 404 — a closed site should not hand a crawler a list of
  everything it has

It is a request, not a lock. It keeps honest crawlers out, not people.

---

## 3a. Per-page controls

§2 gave a resolver a way to *say* things about a URL. This gives an editor a way
to decide them, on a four-tab page form: Content, Navigation, SEO, Advanced.

Tabs because the Content tab is what someone uses every day, and SEO and
Advanced are occasional.

There is deliberately **no Navigation tab**. It looked like one belonged —
parent and menu order both sound navigational — but the Menus screen owns what
appears in a site's menu, and a page carrying its own "navigation" settings gave
two answers to one question. What was on it moved to where it actually belongs:

- **Parent** sits beside the slug on the Content tab, because together they
  *are* the URL. `team` under `About` is `/about/team`. It decides where a page
  lives, not where it appears in a menu, and removing it would have made pages
  un-reparentable.
- **Order** sits at the foot of Content, labelled for what it really does:
  sequence the page tree, and drive the *automatic* navigation a site falls back
  to. Once a curated menu exists, that menu's own order wins. Putting twenty more inputs in front of a person writing
a page makes the common task worse to serve the rare one. They are CSS-only —
every panel stays in the DOM and inside the one form, so switching tabs cannot
lose what has been typed and a save posts every field whichever tab is showing.

### The fields, and what they change

| Field | Effect |
| --- | --- |
| Meta title / description | `<title>`, `<meta name="description">` |
| Meta keywords | `<meta name="keywords">`. Ignored by every major search engine since ~2009; kept because a CMS that silently drops a field an author filled in is worse than one that keeps a harmless one |
| Canonical URL | Overrides the derived canonical outright — the field to reach for when this page duplicates something, including off-site |
| Allow indexing / Follow links | `<meta name="robots">`, emitted **only** when it has something to say |
| OG title / description / image / type | Open Graph, each falling back to the page's own |
| Twitter card | Overridden to `summary` when there is no image — a large-image card with nothing in it looks worse than the plain one |
| Include in sitemap / Priority / Change frequency | Straight into `/sitemap.xml` |
| Publish from / until | A publication *window* |
| Extra head / body markup, JSON-LD | Raw output. See below |

### Defaults are the behaviour that already existed

Every column defaults to what Core did before: indexable, followable, in the
sitemap at 0.5, `og:type` of `website`. An existing row renders identically
after the migration, which is the property that makes it safe to run on a live
site.

### Two rules that resolve contradictions

**A `noindex` page is dropped from the sitemap** whatever its sitemap flag says.
Asking a crawler not to index a page and then advertising it is a contradiction,
and a crawler resolves those however it likes.

**Published and live are different things.** `isPublished()` is an editor's
decision; `isLive()` is that decision plus the clock. A page scheduled for next
Tuesday is published and not live — conflating them would either hide it from
its own author or serve it early. The admin shows a `scheduled` or `expired`
badge for exactly that gap.

The window is applied **in SQL**, not in the caller:

```cfc
liveQuery( siteId )   // status = published
                      //   AND (publish_from IS NULL OR publish_from <= now)
                      //   AND (publish_until IS NULL OR publish_until >= now)
```

A page scheduled for next week must be invisible to *every* caller — the front
controller, the sitemap, a future search index. Filtering in the caller means
the next caller written forgets to.

### Raw markup is a permission, not a field

`head_markup`, `body_markup` and `json_ld` are emitted into every visitor's page
**without sanitising**. That is what they are for, and it makes them the most
dangerous fields in the CMS: anyone who could write them could put a script on a
client's site.

They are gated by the same `content.unfiltered` permission that guards raw HTML
in page content, at two levels — the handler does not read them from the form,
and the service ignores them — so a crafted POST cannot reach the service with
values it will silently drop. An editor without the permission sees an
explanation instead of the inputs.

Everything else is validated regardless of who is asking:

| Input | Rule |
| --- | --- |
| Canonical URL, OG image | `http://`, `https://` or `/` only. `javascript:` in a canonical is inert, but `data:` in an `og:image` reaches places this code cannot see |
| OG type, Twitter card, change frequency | Closed lists. Anything else is dropped, so nothing typed can become an arbitrary attribute |
| Sitemap priority | Clamped to 0–1. A hint is not worth refusing a whole save over |
| JSON-LD | Must parse as JSON. Invalid structured data is silently discarded by every consumer, so an author would otherwise get no feedback at all |

### The `</script>` problem

JSON-LD is valid JSON *and* lives inside a `<script>` element, and those two
have different ideas about where it ends:

```json
{ "name": "</script><script>alert(1)</script>" }
```

That is legal JSON — the service accepts it, correctly. But an HTML parser ends
the script element at the first `</script>` it sees, whatever the JSON around it
says: a script-injection hole hiding inside a data field. The sequence is broken
with a backslash on output, which JSON readers ignore and HTML parsers no longer
recognise as a closing tag.

### One more elvis bug

`variables.robotsIndex ?: true` reads a stored `false` as `true`. A page an
editor had marked `noindex` rendered `index` while being correctly dropped from
the sitemap — the tag and the sitemap disagreed, and only the sitemap was right.
Third instance of the same trap in this codebase, and the reason `?:` is now
treated as a smell wherever a stored value may legitimately be falsy.

---

## 4. Menus

Until now a site's navigation was whatever the installed modules contributed.
That is a sensible default and a poor final answer: an editor could not reorder
it, rename an entry, nest two links under a heading, or link anywhere else.

### An item stores what it points at, not where that is

```
link_type = 'content'  ->  content_type + content_id, resolved at render time
link_type = 'url'      ->  the address itself
```

Storing the URL would mean every menu breaking — or at best redirecting — the
first time an editor renamed a page. Resolving through the owning module keeps
the link exact:

```
rename /about to /about-us  ->  the menu item, and its nested children, follow
```

`LinkTargetRegistry` is how Core stays out of it. Core has no idea what
`pages.page` means; it hands the pair back to whichever provider claims it:

```cfc
array  getLinkTargets( numeric siteId )                              // for the picker
struct resolveLinkTarget( numeric siteId, string type, numeric id )  // or null
```

Returning **null is not an error** — it is how a module reports that a page was
deleted or unpublished.

| Where | An item whose content has gone |
| --- | --- |
| Public site | Dropped. A menu link to a 404 is worse than a missing link |
| Admin | Shown, flagged `missing`, and named — an editor cannot fix what they cannot see |

A child whose parent was dropped goes with it, rather than being promoted to the
top level where nobody put it.

### The fallback is the point

`NavigationService` prefers a curated menu and falls back to the
module-contributed navigation when a site has none.

Without that, shipping this feature would have blanked the navigation of every
site that already existed and had never opened the new screen. A CMS feature
that silently removes a client's menu the day it ships is worse than not
shipping it. Deleting a menu returns the site to the automatic navigation.

Only the header falls back. A theme asking for a `footer` menu nobody has built
gets nothing, not a duplicate of the header.

### Constraints

| Rule | Why |
| --- | --- |
| Two levels, enforced on insert | A theme should never receive a shape it has no markup for |
| `http(s):`, `mailto:`, `tel:`, `/`, `#` only | `javascript:` in a menu is stored XSS on every page of the site |
| Every service call takes a `siteId` | A menu id from a form post never reaches another tenant's navigation |
| Composite FK `(menu_id, site_id)` | The database enforces it too, as `user_roles` does |
| Reordering swaps neighbours | Two writes instead of N, and it cannot renumber an item another editor just moved |

---

## 5. A pre-existing bug this uncovered

The indexable switch is the first **boolean** site setting in the application,
and it could not be turned off. `SiteSettingsRepository` read values through:

```cfc
setting.getSettingValue() ?: ""
```

which looks like a null guard and is not. Storing `"false"` or `"0"` read back
as `""`, and every caller then treated it as "not set".

Nothing had noticed because no setting had ever held a falsy string — the theme
name, the home page id and the contact address are all truthy. Fixed in three
places in that file, with a spec that round-trips `"false"`, `"0"`, `"no"` and
`"off"`.

---

## 6. What is intentionally postponed

| Area | Why it waits |
| --- | --- |
| Sitemap index files | One file caps at 50,000 URLs. The cap is enforced; splitting across files is work nobody needs yet |
| `hreflang` | Needs a translation model, which does not exist |
| JSON-LD structured data | Open Graph covers social previews. Rich results need a decision about which schema types this CMS claims to be |
| Drag-and-drop menu ordering | `moveItem` already does the work; a UI can call it |
| Menu items pointing at a category or tag | The registry accepts any provider; Blog simply does not offer them yet |
| Redirect management UI | `RedirectService` records moves automatically; nothing yet lists or edits them |
