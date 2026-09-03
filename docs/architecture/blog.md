# Blog and Content Sanitising (Group 6)

Two things: closing the stored-XSS hole Group 5 shipped with, and building the
second feature module — which is really a test of whether the seams from
Groups 3-5 hold.

---

## 1. Content sanitising

Group 5 rendered page content unescaped, which made `pages.update` a permission
to run arbitrary script on a client's public site. That is the usual CMS
bargain, but it should be a decision an operator makes for specific people, not
something every editor gets by default.

`ContentSanitizer` in Core wraps ColdFusion's `getSafeHTML` — its OWASP AntiSamy
binding — and is the only place that call appears, so moving engines means
changing one file.

**Content is sanitised by default.** Callers that know the author holds
`content.unfiltered` opt out:

```cfc
pageService.createPage( ..., allowUnfilteredHtml = auth.can( user, "content.unfiltered" ) );
```

The *service* sanitises; the *handler* supplies the trust decision. That keeps
services free of permission logic — the rule since Group 2 — while making the
safe path the default one. A future REST endpoint that forgets to pass the flag
gets sanitising, not a hole.

If sanitising itself fails, the content is **escaped** rather than passed
through. Failing open would publish exactly the markup that could not be vetted;
escaping renders it as visible text, which is wrong but obvious.

`isSafe()` reports whether sanitising would change anything, so an admin screen
can warn an author instead of silently dropping part of their work.

**`content.unfiltered` is not granted to any seeded role explicitly.** `owner`
picks it up because that role is resolved from the whole catalogue at seed time,
which is the intent: a site's owner may embed a video or an analytics snippet;
an editor may not.

---

## 2. Blog

The second feature module. Posts are **flat and chronological**, deliberately
unlike Pages' tree: a blog's structure is its timeline, and categories rather
than a hierarchy are how readers narrow it down.

### Tables

| Table | Notes |
| --- | --- |
| `blog_posts` | `UNIQUE (site_id, slug)` — the lookup behind `/blog/{slug}`. `idx_blog_posts_site_status_date` serves the archive, the one query the blog runs on every visit. `author_id` **SET NULL**, as with pages. |
| `blog_categories` | `UNIQUE (site_id, slug)`, per tenant. |
| `blog_post_categories` | Composite foreign keys, exactly as `user_roles` in Group 2. |

`blog_post_categories` carries a denormalised `site_id` so both foreign keys can
be composite:

```sql
FOREIGN KEY (post_id, site_id)     REFERENCES blog_posts (id, site_id)
FOREIGN KEY (category_id, site_id) REFERENCES blog_categories (id, site_id)
```

Filing one site's post under another site's category is therefore not merely
refused by a service — it cannot be stored. The specs prove it both ways.

### Public URLs

```
/blog                     the archive
/blog/category/{slug}     one category's archive
/blog/{slug}              a single post
```

`BlogContentResolver` registers at **priority 50**, below Pages' 100, so `/blog`
reaches the archive even if a page happens to use that slug. Anything outside
the base path is declined and Pages gets its turn.

An **unknown category 404s** rather than showing an empty list: an empty list
tells a reader the category exists and happens to be bare.

The base path, page size and archive title are module settings.

---

## 3. What Blog proved about the seams

This is the point of building it. Blog adds public URLs, admin screens,
navigation and permissions, and **Core did not change to accommodate any of it**:

| What it needed | Seam it used | Built in |
| --- | --- | --- |
| Public URLs | `ContentResolverRegistry` | Group 4 |
| A menu entry | `SiteNavigationRegistry` | Group 6 |
| Admin screens | own entry point + `SecuredHandler` | Group 5 |
| Admin navigation | `AdminNavigationRegistry` | Group 5 |
| Permissions | own migration into Core's catalogue | Group 2 |
| Safe content | `ContentSanitizer` | Group 6 |
| Persistence helpers | `BaseRepository` | Group 1 |

Building it also *found* a gap rather than merely fitting into one: navigation
was part of the content resolution, so the site menu vanished on every blog URL.
That produced `SiteNavigationRegistry` — see
[routing-and-themes.md](routing-and-themes.md). A second module was the only
thing that could have exposed it.

It depends on Core alone and knows nothing of Pages. The one thing a module
*must* supply beyond code is **theme views**: a theme has to provide
`blog-index` and `blog-post` for a site to serve a blog, and `ThemeService`
raises a typed `Theme.ViewMissing` when it does not.

---

## 3a. Title versus heading

Posts carry the same `show_heading` switch as pages, and for the same reason: a
post whose content opens with its own headline had that headline twice, once
from the theme and once from the author. See
[pages.md §4a](pages.md#4a-title-versus-heading) for the reasoning — this is a
*display* switch, not a way to have a post without a title, and the title
remains the browser tab, the `<title>` tag, the archive listing and the link
text when it is off.

Its own column on `blog_posts`, following the precedent this table already sets
by keeping its own `meta_title` and `meta_description` rather than sharing
Pages'. A join on every post render to avoid one `ALTER TABLE` is the wrong
trade; a third content type wanting this is the moment to generalise.

One difference from the pages implementation, and it matters. Page options
travel in a struct, so `structKeyExists` distinguishes "set to false" from "not
supplied". `updatePost` takes plain arguments instead, so `showHeading` is
declared **without a default** and read through `isNull()`. A default of `true`
would quietly turn the heading back on every time a post was edited from
anywhere that did not mention it — the admin handler leans on this by adding the
key to its argument struct only when the form actually carried the field.

## 4. What is implemented

- `ContentSanitizer`, the `content.unfiltered` permission, and sanitising wired
  into both Pages and Blog.
- `blog_posts`, `blog_categories`, `blog_post_categories`.
- Entities, repositories and `BlogService`, with categories loaded on request
  rather than always.
- `BlogContentResolver` and the three public URL shapes.
- Admin screens for posts and categories, contributed by the module.
- Per-post `show_heading`, so a post whose content carries its own headline does
  not print the title twice.
- `blog-index` and `blog-post` views in both themes.
- 47 passing specs for this group; 470 across Groups 1-7.

## 5. What is intentionally postponed

| Area | Why it waits |
| --- | --- |
| Canonical tags on paged archives | `/blog` and `/blog/page/1` render the same content at two addresses. A `rel="canonical"` tag is the fix, and it belongs with the SEO area. |
| Tags, in addition to categories | Categories cover the current need. Tags are a second many-to-many with the same shape and no new lessons. |
| RSS / Atom feeds | Straightforward once someone asks; a resolver returning XML rather than a theme view. |
| Scheduled publishing | Needs a job runner, still out of scope. |
| Comments | A different problem — moderation, spam, and untrusted public input. |
| Related posts, archives by month | Reader features; no requirement yet. |
| Per-site base path | The blog lives at `/blog` for every site, from a module setting. A site setting would be the natural upgrade. |
| Warning an author when sanitising removed something | `isSafe()` exists for exactly this; no screen calls it yet. |

---

## 6. Paged archives

The archive showed the first ten posts and offered **no URL for the rest**, so
everything older was unreachable rather than merely inconvenient. A blog that
quietly hides its own back catalogue is broken, not incomplete.

```
/blog                            newest ten
/blog/page/2                     the next ten
/blog/category/craft             a category, paged independently
/blog/category/craft/page/2
```

Paging lives in the **path**, not a query string: a content resolver is handed
the path and nothing else, and a path is something a person and a search engine
can both read.

**A page beyond the last is a 404**, not a repeat of page one. Serving page one
under a `/page/9` URL would put one page's content at another page's address —
the thing `Paginator.isValidPage` exists to prevent. `/blog/page/0`,
`/blog/page/abc` and `/blog/page/2/extra` are refused for the same reason, and a
single post takes no page suffix at all.

Links back to page one point at `/blog` rather than `/blog/page/1`, so the
archive has one canonical address rather than two.

## 7. A note on migration atomicity

The blog migration failed midway on its first run, and MySQL DDL auto-commits —
so two of three tables existed while the migration was recorded as unapplied.
Re-running then failed confusingly with "table already exists".

Nothing is wrong with the migration now, but the hazard is inherent: **a
multi-table migration is not atomic on MySQL.** When one fails partway, drop
whatever it created before re-running. Splitting each table into its own
migration would contain the blast radius, at the cost of more files.
