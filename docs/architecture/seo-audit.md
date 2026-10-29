# SEO Audit

Finds on-page SEO problems across every public URL of a site, and stores what
it found so the report can be read later and compared with last week's.

`/admin/seo`, behind `seo.view`. Starting a run needs `seo.run`.

---

## 1. The decision everything else follows from

**The audit reads the rendered page, not the database.** It fetches each URL
over HTTP, parses the response, and asks each check what is wrong with it.

Reading the database would be faster, simpler and need no network. It would also
be unable to answer the questions that matter most:

| Question | Why the database cannot answer it |
| --- | --- |
| Does this page have exactly one `<h1>`? | The theme emits one when `showHeading` is on, **and** an author may write their own in the content. Neither row in `pages` is wrong. Only the output has two. |
| Does every image have alt text? | `[image]` and `[file]` shortcodes expand at render time, and a featured image may be **inherited** from an ancestor. None of those `<img>` tags exist in stored content. |
| Is `/faq` all right? | It is not a `pages` row at all. `/faq`, `/contact` and the other module landing pages are served by content resolvers. |
| Does this URL even answer? | A 404 or a redirect is not a property of a row. |

A database audit would report a confident page count while silently skipping a
third of the site. That is worse than no audit, because somebody would trust it.

### The cost, and where it is paid

A run is one HTTP request per URL, sequentially, so a hundred-page site takes
seconds rather than milliseconds. It happens on a **background thread**:
`start()` creates the row, hands the work off and returns, and the report reads
progress off the row. `maxUrls` (default 250) is the ceiling.

Three things have to be settled on the request thread, before the hand-off,
because they are unavailable or wrong on the other side of `cfthread`:

- **The fetch base URL.** It reads `cgi.server_port`, and `cgi` is empty in a
  thread — a run that derived it there would fetch port 80 and report every page
  on the site as unreachable.
- **Whether a run is already going.** Two concurrent crawls double the load a
  site puts on itself for no extra information, so a second `start()` throws
  `SeoAudit.AlreadyRunning`.
- **Clearing a dead run.** See below.

An exception inside the thread is invisible to whoever started it, so the thread
records its own failure on the row.

### Progress, and runs that die

`url_count` and `queued_count` are written every fifth URL, along with
`heartbeat_at`. The report shows both counts and **no percentage**: a crawl
discovers URLs from the pages it has already fetched, so there is no
denominator, and a progress bar would need one that does not exist.

A thread killed by a restart, a deployment or an out-of-memory cannot mark its
own row failed. Without a guard the row stays `running` for ever, the report
polls for ever, and every later audit of that site is refused as a duplicate.
`reconcileStalled()` marks anything `running` whose heartbeat is older than
`stallMinutes` (default 15) as failed, and is called both when the screen loads
and before a new run starts.

---

## 2. Parsing, without a parser

CFML has no HTML DOM. `xmlParse` needs well-formed XML and real pages are not:
unclosed `<p>`, bare `<img>`, unquoted attributes.

**TagSoup** solves it, and it is already on ColdFusion's own classpath
(`tagsoup-1.2.jar`) — so this adds no dependency and nothing to deploy. It is a
SAX parser built for real-world HTML: it reads markup the way a browser does and
emits well-formed XML, which `xmlParse` accepts and `xmlSearch` queries with
XPath.

```
HTML → TagSoup → XML string → xmlParse → XPath
```

`HtmlDocument` is the only place that knows this. Namespace processing is turned
off deliberately — left on, every element lands in the XHTML namespace and every
XPath needs a registered prefix.

Two details in there earn their keep:

- **`alt=""` is not a missing `alt`.** An empty alt is the correct way to mark an
  image decorative. `images()` reports whether the attribute is *present*, which
  is a different question from whether it has a value. Collapsing the two would
  make the check nag about images that are already right.
- **Word count excludes `<script>`, `<style>` and `<noscript>`** — said as one
  XPath (`not(ancestor::script)`), not by walking the tree, because `xmlText` on
  an element returns its descendants' text concatenated and a walk cannot
  separate a node's own text from a script nested inside it.

Navigation, header and footer text *is* counted. Excluding it would mean deciding
what counts as content rather than measuring. The consequence is that the count
overstates how much a page says, which is why the thin-content threshold is set
low rather than at "good content".

---

## 3. Which URLs get audited

Two sources, because neither is complete.

**The sitemap** (`SitemapRegistry`) is what the site claims it publishes. It is
the right seam — but only Pages and Blog register a provider today, so `/faq`,
`/contact` and the other module landing pages are absent from it.

**Internal links** fill the gap. Every fetched page is parsed anyway, so its
links cost nothing extra, and following them reaches `/faq` because the theme
links it from the navigation.

Seeded URLs are queued first, so the sitemap's content is always audited before
the budget goes on discovered extras. The crawl is breadth-first and bounded.

### What is never followed

Served files (`/media/...`), the admin, other hosts, `mailto:`/`tel:`, and
anything whose extension is not a page. Fetching a 20MB PDF to inspect its
`<title>` would spend the budget on something that has none.

A relative link (`team`, `../team`) is skipped rather than resolved. This CMS
emits absolute paths everywhere, and inventing a base would mean auditing a URL
that does not exist.

`pathFromLink` returns **null** for "not a link worth auditing" and an **empty
string** for the home page. Those are different answers, and using `""` for both
would make `mailto:` indistinguishable from `/`.

---

## 4. Fetching

`cfhttp` **through the hostname the admin request already arrived on**, when
that hostname is one of the site's own. It is reachable by proof — the request
got here through it — the scheme is known for the same reason, and no `Host`
header has to be overridden.

### The version that shipped first, and why it failed

It derived `http://127.0.0.1:<cgi.server_port>` and overrode `Host` with the
site's primary domain. That is correct on a developer's machine and wrong on
every TLS site: `cgi.server_port` is 443, so the run spoke plain HTTP to an
SSL-enabled port, and Apache answered **400 Bad Request** to all 173 URLs of
the first real site it was pointed at. The audit was never reaching the site at
all.

Worth recording what was *not* the cause, since it looked likelier: adding a
`Host` header via `cfhttpparam` does **not** produce a duplicate header.
ColdFusion replaces it — confirmed by capturing the bytes on a socket — so a
request with multiple `Host` fields, which a server must reject with 400, was
never being sent.

### The fallback, and when it applies

Loopback with a `Host` override remains for the case it was really written for:
a developer's machine, where `something.test` does not resolve in DNS and the
admin is reached on `127.0.0.1`. Choosing between them is a question with a
factual answer — is the request's host one of this site's domains? — rather
than a guess about the deployment.

`fetchBaseUrl` overrides both, for a server that can reach itself at neither
address.

### Saying so when it cannot reach the site

One identical error per URL is a report that says nothing. When at least 90% of
a run's URLs fail — on a crawl of three or more — it adds a single
`site.unreachable` error naming the address tried, the status codes that came
back, and the fact that a 400 on everything usually means HTTP against an HTTPS
port. The threshold is high on purpose: a site where a quarter of pages 404 has
a real problem worth reporting page by page.

No cookies ride along, so every page is fetched as an anonymous visitor. That is
deliberate: an audit should see what the public sees, not a draft visible to
whoever started the run.

---

## 5. Checks

A check is any object with `inspect( document, context )` returning findings.
Registered on `SeoCheckRegistry`, the same seam as every other registry here, so
a module can contribute a check about its own content without this module
knowing it exists. A check that throws is skipped with a warning — one broken
check must not cost the other eight on every URL.

Severity is the editorial judgement in this module, and it is deliberate:

| Severity | Means | Checks |
| --- | --- | --- |
| **error** | Costs traffic, or the page is broken | no title, no `h1`, **more than one `h1`**, canonical pointing elsewhere, non-200, unparseable, no primary domain |
| **warning** | Works, but leaves value on the table | title/description length, duplicate-looking title, missing `alt`, thin content, redirect, **`noindex`**, **structured data that is broken or untyped** |
| **notice** | Worth knowing, not worth alarm | Open Graph tags, skipped heading level, underscores or capitals in a URL, no analytics tag, **`nofollow`**, **no structured data at all** |

A canonical pointing elsewhere is an error and not a warning because it is the
most damaging single fault on the list: the page disappears from results and
nothing on the page looks wrong.

Open Graph findings are notices because they affect **what a shared link looks
like**, not ranking. Ranking them alongside a broken canonical would be
dishonest about what matters.

Site-level findings are recorded **once**, against the empty path. "This site has
no Google tag" repeated on all hundred pages would be true and useless.

### `noindex` is a warning, not an error

It is the single most consequential tag on a page — the page is removed from
results entirely and nothing about it looks wrong — but this CMS has an explicit
`robotsIndex` switch, so it can be a deliberate choice: a thank-you page after a
form, a print variant, a staging tenant. A warning says "look at this" without
claiming it is a fault. It is reported on **every** page that carries it, because
the only way for it to stop appearing is for somebody to decide it is correct.

The check reads the comma list rather than looking for a substring: `noindexing`
is not `noindex`, and a substring test would report a page that is perfectly
indexable. `robots.txt` and the `X-Robots-Tag` header can exclude a page just as
effectively and neither is in the markup — the header is thrown away by the
fetcher, and `robots.txt` is a site-level question.

### Structured data stops at `@type`

Checking that a `Product` has an `offers` with a `price` means encoding Google's
rich-result requirements, which are long, per-type, and change without notice. A
check that is confidently out of date is worse than one that is honestly
shallow.

What it does catch is the failure that is otherwise invisible: **JSON-LD fails
silently**. A trailing comma or a smart quote pasted from a word processor, and
the block is ignored, the page looks completely normal, and nothing says the
markup somebody spent an afternoon on is doing nothing. That is a warning, and
the detail names which block when a page carries several — a `WebSite` block in
the layout plus an `Article` block on the page is normal.

Three shapes are all legal and all appear in the wild: one object, an array of
them, and an object whose `@graph` holds the list. Only the top level of each is
examined — a nested `author` with its own `@type` does not make an untyped
parent typed, and recursing would find one and call the block fine. An array
needs **every** entry typed: one typed object in a list of five does not make
the other four usable.

---

## 6. Crawl-wide checks

Some questions are not about a document at all. "Two pages share a title" and
"this link goes to a 404" are questions about the **set**, and a per-page check
cannot see the other ninety-nine pages.

So there is a second registry, `SeoCrawlCheckRegistry`, with a different
contract: `inspect( pages, context )`, where `pages` is what the crawl collected
for each URL — path, status, title, description, canonical, internal links, and
whether it came from the sitemap or was found by following a link. Findings carry
their own `path`, because a crawl check chooses which page to blame.

The collected data is gathered **during** the crawl, not by keeping the parsed
documents: holding a hundred DOMs in memory to ask them two questions afterwards
would be the expensive way round.

### Broken links

Reported against the page **containing** the link, never the missing page —
that page does not exist, so there would be nothing to open and fix.

Two deliberate limits:

- **Only internal links.** Checking external ones means an outbound request per
  link to a third party: slow, dependent on other people's uptime, and it reports
  this site as broken when someone else's server is briefly down.
- **Only targets the crawl actually reached.** A link may point past `maxUrls`.
  That is unknown, not broken; reporting it would mean a bigger site produced
  hundreds of findings saying only "the audit ran out of budget".

### Duplicate titles and descriptions

Reported on **every** page in the group, because there is no basis for calling
any one of them the duplicate and whoever fixes it needs all the addresses. The
detail names the others, not the page being reported.

Grouped on the lowercased, whitespace-collapsed value: two titles differing only
in case or spacing are the same title to a reader and to a search engine.

A title is a **warning** and a description a **notice** — a shared title dilutes
ranking, a shared description only looks repetitive and is frequently rewritten
by Google anyway. Pages with *no* title are not grouped: "nine pages share the
same blank title" is true and useless, and the missing title is already reported
per page.

Near-duplicate *bodies* are deliberately not detected. That needs shingling and
a judgement about how similar is too similar, and the common CMS cause — one page
reachable at two URLs — is already covered by the canonical check.

### Sitemap reconciliation

Both halves were already collected, so comparing them is free and turns two
silent gaps into findings:

- **In the sitemap, linked from nowhere** — an orphan. Crawlers follow links to
  judge importance, so it ranks poorly however prominently the sitemap lists it.
  Usually a page dropped from a menu and never unpublished. A warning.
- **Linked and working, absent from the sitemap** — often deliberate, since
  `PageSitemapProvider` honours "exclude from sitemap" and skips `noindex`. A
  notice, and the message says it may be intentional.

The home page is never called an orphan: it is what the bare domain serves, so
it is reachable whether or not anything links to it.

Worth knowing when reading a report: `NavigationService` falls back to listing
published top-level pages when a site has no menu, so on such a site a top-level
page is never an orphan and a child page usually is.

---

## 7. Storage

`seo_audits` is a run; `seo_audit_issues` are its findings. Both carry `site_id`
and every read is scoped by it.

A finding stores its **URL as text**, not a foreign key, with a nullable
`page_id` alongside purely so the report can offer an "edit this page" link.
Two reasons, the second deciding:

- Not every audited URL is a page.
- A finding is a statement about the past. If a page is renamed after a run, the
  finding should still read as what was true then, rather than following the
  page or vanishing.

`page_id` is populated from `LinkTargetRegistry` — the seam the menu editor
already feeds — so this module needs no dependency on Pages or Blog, and a
module that teaches the menu editor about its content teaches this at the same
time.

### Two traps worth recording

**qb binds an empty string as NULL.** For most columns that is harmless. Here it
is not: an empty `path` is a real value — the home page, recorded as `""`
everywhere in this CMS — and left to inference, every finding about the home page
was rejected with `Column 'path' cannot be null`, which took the whole run down.
String columns are now bound explicitly with `null : false`.

**`reFind` with `returnSubExpressions` returns `len` and `pos` as arrays**, not
numbers. Using `code.len` as a boolean throws "cannot convert ArrayList to a
boolean". It is `code.len[ 1 ]`.

**Arrays are passed by value in CFML; structs are passed by reference.** The
crawl queue is an array, and a private method that appended to
`arguments.queue` appended to a *copy* — so every discovered link was silently
dropped and the crawl only ever audited what the sitemap already listed.
Nothing failed, because the test fixtures were all in the sitemap too. The
`seen` struct in the same function worked perfectly, which made it harder to
see. `enqueueLinks` now returns the queue and the caller reassigns it.

---

## 8. The report

Two tabs over one set of findings, grouped twice in SQL rather than reshuffled
in the view, because there are two different jobs:

- **By problem** — "what is wrong with this site", read once after a run.
- **By page** — "what do I fix here", read while editing.

Plus **History**, so two runs can be compared by opening both.

Severity is always shown as a word as well as a colour. A list someone is being
asked to prioritise cannot encode priority in hue alone.

---

## 9. Auditing one URL, now

`SeoAuditService.auditOne()` fetches one path, runs every registered per-page
check against it, and returns the findings. It writes no row and spawns no
thread, and that is the whole difference from a run:

| | A run | One URL |
| --- | --- | --- |
| Scope | Every public URL, bounded by `maxUrls` | One path |
| Where it happens | A background thread, with the run row as its progress record | In the request |
| What it leaves behind | A `seo_audits` row and its findings | Nothing |
| How the caller gets the answer | Polls the run until it stops being `running` | In the response |

It exists because an editor checking the page they just saved, six times in a
row, must not leave six runs in a report nobody will read — and must not trip
`SeoAudit.AlreadyRunning` for the real nightly crawl.

Because every *registered* check runs, a check added for the admin report
appears here with no further wiring. The three **crawl** checks do not apply:
they answer about a set, and there is no set.

### Except broken links, which do apply

A link to a 404 is one of the most useful things a single-page audit can report,
so `auditOne` builds `BrokenLinkCheck` the set it needs: the page itself, plus a
stand-in entry per link target carrying nothing but the status its fetch came
back with. That reuses the real check, so the single-page answer cannot drift
from the nightly report's.

The other two crawl checks are deliberately *not* run over that set. Every
stand-in has an empty title and was never in a sitemap, so duplicate-content and
sitemap reconciliation would report findings about fixtures the method invented.

It costs one fetch per link, so it is capped by `pageLinkBudget` (25) and can be
switched off by the caller. Links beyond the budget are left unjudged rather
than reported as unknown — the same rule a run follows when it hits `maxUrls`.

---

## 10. What is intentionally not here yet

| Area | Why it waits |
| --- | --- |
| **External link checking** | An outbound request per link to a third party. Slow, and it reports this site as broken when someone else's server is down. Belongs on its own schedule, not as a side effect of auditing markup. |
| **Concurrency within a run** | Pages are fetched one at a time. Fetching four at once would cut a large run's wall time, at the cost of four CF threads against the server itself. |
| **Near-duplicate content detection** | Needs shingling or hashing and a judgement about how similar is too similar. The common CMS cause is already covered by the canonical check. |
| Scheduled runs | No scheduler in the app. `POST /api/v1/seo-audits` with a token now makes a cron job a one-liner. |
| Image weight and dimensions | Needs a request per image. |
| Structured data validation beyond `@type` | Encoding Google's per-type rich-result requirements, which change without notice. Their own tool does it well. |
| Per-site thresholds | `titleMax`, `thinContent` and the rest are module settings, so they are the same for every site on the installation. |
