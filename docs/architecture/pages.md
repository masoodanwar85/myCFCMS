# Pages (Group 3)

The first feature module: hierarchical, per-site content pages.

Read [multi-tenancy.md](multi-tenancy.md) and [access-control.md](access-control.md)
first — pages hang off `sites` and are governed by the permission model.

---

## 1. What this module proves

Groups 1 and 2 built Core. This one is the first thing built *on* Core, and its
job is as much structural as functional: it is the template Blog, News and
Contact will copy. The step-by-step, using Contact as the worked example, is
[creating-a-module.md](../guides/creating-a-module.md).

```
app/modules/
    core/      <-- knows nothing about pages
    pages/     <-- depends on core, and on no other feature module
```

Concretely, the module is self-contained in three ways:

- **Its own table.** `pages` belongs to this module. Core never reads it.
- **Its own permissions.** `pages.view`, `pages.create`, `pages.update`,
  `pages.delete`, `pages.publish` are registered into Core's catalogue by this
  module's own migration. Core stores the slugs without knowing what they mean.
- **Its own events.** `onPageCreated`, `onPageUpdated`, `onPagePublished`,
  `onPageUnpublished`, `onPageDeleted` let later modules — menus, search
  indexing, cache invalidation — react without this module knowing they exist.

Even the home page follows the rule. A site records which page it serves at its
root in a **site setting** (`pages.homePageId`), not in a column on `sites`, so
Core needs no knowledge of pages and a site without this module simply has no
such setting.

---

## 2. Database strategy

One table, InnoDB / `utf8mb4` / `utf8mb4_unicode_ci`.

| Column | Type | Notes |
| --- | --- | --- |
| `id` | `BIGINT UNSIGNED` | PK |
| `site_id` | `BIGINT UNSIGNED` | FK → `sites.id`, cascade |
| `parent_id` | `BIGINT UNSIGNED` NULL | FK → `pages.id`, cascade. NULL = top level |
| `title` | `VARCHAR(255)` | |
| `slug` | `VARCHAR(191)` | This page's URL segment |
| `path` | `VARCHAR(500)` | Full path, e.g. `about/team` |
| `status` | `VARCHAR(20)` | `draft` / `published` / `archived`, `CHECK`-constrained |
| `content` | `MEDIUMTEXT` NULL | |
| `meta_title`, `meta_description` | `VARCHAR` NULL | Per-page SEO |
| `sort_order` | `INT` | Order among siblings |
| `published_at` | `DATETIME` NULL | |
| `created_by`, `updated_by` | `BIGINT UNSIGNED` NULL | FK → `users.id`, **SET NULL** |
| `created_at`, `updated_at` | `DATETIME` | |

### The tree, and why the path is stored too

Pages form a tree through `parent_id`, because a site's structure *is* a tree
and menus, breadcrumbs and URLs all read it as one.

But resolving `/about/team` by walking that tree means one query per level, on
every request. So each page also stores its full `path`, and
`UNIQUE (site_id, path)` makes resolution a **single unique-index read**. That
index is doing double duty: it is the router's lookup *and* the reason two
siblings cannot share a slug, since they would produce the same path.

The cost is real and worth stating: **a rename or a move has to rewrite the
paths of every descendant.** `PageService` owns that, and does it in one
`UPDATE` over a path prefix rather than a query per descendant — a partial
failure would otherwise leave the tree inconsistent. The specs pin it at three
levels deep, and pin that another site's identical paths are left alone.

### Deletion

`parent_id` cascades, so the tree can never be orphaned — a page pointing at a
parent that no longer exists is unreachable and unfixable through the UI.

Because that cascade is destructive, `PageService.deletePage()` **refuses** to
delete a page that has children unless the caller passes
`includeDescendants = true`. The database guarantees integrity; the service
guarantees you meant it.

`created_by` / `updated_by` do the opposite and **SET NULL**: removing a user
must not remove their pages. They reference `users.id` plainly rather than the
composite `(id, site_id)` key used in Group 2, because a platform super admin
belongs to no site and must still be recordable as an author.

---

## 3. Service layer

`PageService` owns three things the repository deliberately does not.

**Tree integrity.** A page cannot be moved beneath itself or beneath its own
descendant; either would detach the subtree and leave a cycle no query
terminates on. The materialised path makes this an O(1) prefix check rather
than a walk.

**Path correctness.** Building a path from parent plus slug, and rewriting a
subtree after a rename or move.

**Publishing.** `published_at` is stamped on the *first* publish only, so
correcting and republishing a page does not rewrite its original publication
date.

```cfc
property name="pages" inject="PageService@pages";

var page = pages.createPage( siteId = 1, title = "About Us" );          // path: "about-us"
var team = pages.createPage( siteId = 1, title = "Team", parentId = page.getId() );

pages.publishPage( team.getId() );
pages.movePage( team.getId(), someOtherPage.getId() );                   // rewrites subtree
pages.getPublishedPageByPath( 1, "/about/team/" );                       // the router's call
```

| Read | Returns |
| --- | --- |
| `getPageByPath` | Any status — the editor's view |
| `getPublishedPageByPath` | Published only — the public view |
| `getTree` | Nested `{ page, children }`, one query, sorted in menu order |
| `getBreadcrumb` | Ancestors outermost-first, derived from the path |
| `getDescendants` | Everything beneath a page, by path prefix |

Path lookups are normalised, so `/about/team/`, `about/team` and `/About/Team`
all resolve to the same page.

---

## 4. Errors

| Type | Raised when |
| --- | --- |
| `Pages.SiteNotFound` | The target site does not exist |
| `Pages.PageNotFound` / `Pages.ParentNotFound` | Unknown id |
| `Pages.InvalidPage` | Empty title, unusable slug, unknown status |
| `Pages.PathAlreadyExists` | The site already has a page at that path |
| `Pages.CrossTenantParent` | Parent belongs to another site |
| `Pages.CrossTenantPage` | Page belongs to another site |
| `Pages.CircularHierarchy` | A move would put a page beneath itself |
| `Pages.PageHasChildren` | Delete refused; pass `includeDescendants` |
| `Pages.InvalidAuthor` | Author is not of this site and not a super admin |

---

## 4a. Title versus heading

A page's title does five jobs: the `<h1>` on the page, the browser tab, the
`<title>` tag, the menu label and the breadcrumb. `show_heading` unpicks the
first from the other four.

It exists because some pages carry their own headline in the content — a
landing page opening with a hero, or a body whose first element is a styled
title block — and the theme's `<h1>` above it printed the same words twice. The
only workaround was to name the page something blank-looking, which then broke
the tab, the menu and the breadcrumb.

So it is a **display switch, not a second title**. With it off the page still
has a title everywhere a title is used; only the on-page heading goes. A page
whose heading is hidden has no `<h1>` of its own, which the field's help text
says outright — the content is expected to supply one.

The column defaults to `1`, so every row that existed before it renders exactly
as it did.

### Writing your own

Hiding the theme's heading is only half of it — the author then needs to be able
to write one. The editor's style menu used to start at **Heading** (`h2`), on
the reasoning that the theme supplied the `h1` and a second one would be wrong.
With `show_heading` that reasoning inverts, and the option became a dead end:
turn the heading off and the page had no `h1` at all, with no way to add one.

The style menu now opens with **Page heading** (`h1`). The sanitiser had allowed
`h1` through `h6` all along — only the toolbar withheld it — so nothing about
storage or the policy changed.

The pair does create one trap: heading on *and* an `h1` in the content is two
top-level headings, which nothing would otherwise report and which reads as two
competing titles to a screen reader and to a crawler. The editor flags it, with
a substring check on the markup rather than a parse — a hint that is
occasionally over-eager costs nothing, and a parser on every form render costs
something every time.

It travels in the same `seo` struct as the SEO fields, which is where the extra
page options already ride — scheduling and raw markup are in there too, and
neither is SEO. `PageService` handles it in its own `applyDisplay()` next to
`applySchedule()` and `applyRawMarkup()`, so the distinction stays visible even
though the transport is shared.

Read with `structKeyExists`, never truthiness: `false` is the whole point of the
field, and the elvis shortcut would make it impossible to turn off — the same
trap that has caught `robotsIndex`, `sitemapInclude` and site settings before.

## 5. What is implemented

- The `pages` table with hierarchy, materialised paths, SEO fields, publishing
  states and authorship.
- Five module permissions, registered by the module's own migration.
- Entity, repository and service, with full tree and path maintenance.
- Five interception points for later modules to hang off.
- Home-page designation via Core's site settings.
- Per-page `show_heading`, so a page whose content carries its own headline does
  not print the title twice.
- 70 passing specs for this group; 258 across Groups 1–3.

## 6. What is intentionally postponed

| Area | Why it waits |
| --- | --- |
| Routing and rendering | **Delivered in Group 4.** The module still registers no routes; it supplies a content resolver that Core asks. See [routing-and-themes.md](routing-and-themes.md). |
| Permission checks inside the service | Still deliberate. Enforcement arrived in Group 5 at the request boundary — see [admin.md](admin.md) — leaving the service callable by CLI tasks and migrations. |
| Revisions / version history | A real requirement, and a table of its own. No use case demands it yet. |
| Scheduled publishing | `published_at` records when a page went live, not a future intent. Scheduling needs a job runner, which is explicitly out of scope. |
| Slug transliteration for non-Latin scripts | Latin accents now transliterate (`Café Münster` → `cafe-muenster`) via Core's `Slugifier`. Scripts with no Latin equivalent — Greek, Cyrillic, CJK — still drop out, and a title entirely in one produces an empty slug the author must fill in. |
| Templates / layouts per page | Belongs with themes. |
| Content blocks, shortcodes | Core areas of their own. |
| Full-text search | Needs a decision on MySQL full-text versus an external index. |

---

## 7. A note on the datetime fix

Group 3 surfaced a defect affecting **all three groups**: the JVM ran in
`Asia/Karachi` while ColdFusion's `this.timezone` and MySQL were both UTC, so
every `DATETIME` was written correctly but read back five hours early. Every
`created_at`, `updated_at` and `published_at` in the system was affected.

Fixed by pinning the JVM to UTC (`-Duser.timezone=UTC` in `server.json`) and
setting `useLegacyDatetimeCode=false`, which stops the driver converting through
the JVM default zone. Round-trip drift is now zero.

The architectural rule this makes explicit: **store and compute in UTC; present
in the site's timezone.** `sites.timezone` exists for the presentation half, and
is not yet applied anywhere because nothing renders yet.
