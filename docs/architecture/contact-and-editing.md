# Contact Forms and Rich Text Editing (Group 7)

Two things: a rich text editor for content, and the first module that accepts
input from people who are not signed in.

---

## 1. Rich text editing

CKEditor 5, **self-hosted** under `public/includes/vendor/ckeditor5/`, not loaded
from a CDN. The admin should work on a machine with no outbound internet, and a
CDN outage should never take away a client's ability to edit their own site.

Loaded only where content is edited. The build is ~1.8MB, and the dashboard,
users and roles screens have nothing to edit, so `Core/layouts/Admin.cfm`
includes it when a handler sets `prc.useEditor`. Any `textarea[data-editor]` on
the page is upgraded — so a module opts in by adding one attribute.

If the script fails, the plain textarea is still there and still submits.
Editing degrades rather than breaking.

**No image tools are configured.** There is no Media library, so an image button
would offer something the CMS cannot store.

### Licensing — worth a decision

CKEditor 5 is **dual-licensed: GPL 2+ or commercial**. The integration passes
`licenseKey: "GPL"`, which selects the open-source terms.

For 8–10 sites you host yourself that is straightforward, since GPL obligations
attach to *distribution* and hosting is not distribution. If myCFCMS is ever
shipped to a client to run themselves, or sold as a product, that changes and a
commercial CKEditor licence is the usual answer. Flagging it now because it is
much cheaper to swap editors today than after a client is live on one.

### The conflict this exposed

Group 6 sanitises content with ColdFusion's `getSafeHTML`. Its bundled policy,
`antisamy-basic.xml`, allows about a dozen tags — **no headings, no tables, no
horizontal rules, no underline or strikethrough**.

Sanitising with it silently deleted exactly what the new toolbar produces. An
author would have written a heading, saved, and watched it turn into a
paragraph, with nothing to explain why.

So the CMS ships its own AntiSamy policy at
`resources/security/antisamy-cms.xml`, allowing what an editor legitimately
writes and nothing that can execute. Verified in both directions:

| Kept | Blocked |
| --- | --- |
| headings, tables, lists, blockquote | `<script>` |
| bold, italic, underline, strikethrough | `onerror`, `onclick`, every `on*` |
| links, horizontal rules, `<figure class="table">` | `javascript:` URLs |
| images (nothing produces them yet — content survives a later Media library) | `<iframe>`, `<object>`, `<form>` |

---

## 2. Contact

The third feature module, and the first whose write path is **reachable by
anyone on the internet**. Every other write in the CMS sits behind
authentication and a permission.

That changes what the code has to assume. `ContactService.submit()` treats its
caller as hostile: values are validated and length-capped, the message is stored
as text and never as markup, and repeated sends from one address are throttled.

### Tables

| Table | Notes |
| --- | --- |
| `contact_forms` | Per site. Most sites need one; a site with separate sales and support addresses needs two, and that is cheaper to allow now than to retrofit. |
| `contact_submissions` | Composite foreign key `(form_id, site_id)`, so a message cannot be attached to another site's form. Carries `ip_address` and a `new`/`read`/`spam` status so a human can triage rather than delete. |

### How Core had to grow

Public content that accepts input needs somewhere for the POST to go. Giving
each module its own public route would mean every module reaching into the
application router, with ordering deciding who won.

So a resolver may now optionally implement:

```cfc
struct|null handleSubmission( numeric siteId, string path, struct formData )
```

It receives the submitted values as a **plain struct** — not the event, not the
request — so a module still knows nothing about HTTP. It returns a resolution to
render, optionally carrying `redirectTo` for the redirect-after-post that stops
a refresh resending.

```
GET  /contact             the form
POST /contact             -> handleSubmission -> redirect
GET  /contact/thank-you   a page that is safe to reload or bookmark
```

### Defences, and what each is for

| Control | Stops | Behaviour when tripped |
| --- | --- | --- |
| CSRF token | Another site posting on a visitor's behalf | Form redisplayed, `422`, nothing stored |
| Honeypot field | Bots that fill every input they find | **Answers exactly like a success**, stores nothing — a bot learns nothing about why it failed |
| Throttle (5/hour per address) | A flood from one sender | Refused with a plain message |
| Length caps | Using the form to fill the database | Refused before anything is written |
| Escaped output in the admin | A submitted `<script>` running when staff read it | Rendered as text inside `<pre>` |

The throttle counts existing rows rather than keeping state of its own, so it
survives a restart and needs no extra store. It is crude and useless against a
distributed flood — a real rate limiter belongs at the edge — but it stops the
obvious case.

`X-Forwarded-For` is only consulted when `trustForwardedFor` is set, because it
is trivially forged by whoever is sending the requests.

### Email is not sent yet

There is still no mail layer. Submissions are stored and shown in the admin, and
`sendNotifications` is off. The notify path exists and is best-effort by design:
**a failure to notify must never lose a message that has already been stored.**

---

## 3. What is implemented

- CKEditor 5, self-hosted, on the page and post content forms.
- A CMS AntiSamy policy that preserves editor markup and still blocks script.
- `contact_forms` and `contact_submissions`, with composite tenant keys.
- `ContactService`, resolver, navigation provider and admin screens.
- `handleSubmission` on the resolver contract, and POST routing in Core.
- Three permissions, separating reading enquiries from configuring forms.
- 424 passing specs across Groups 1–7.

## 4. What is intentionally postponed

| Area | Why it waits |
| --- | --- |
| Email notification | Needs a mail layer. This is now the single biggest gap: it also blocks password reset and user invitations. |
| CAPTCHA | The honeypot and throttle handle ordinary spam. A CAPTCHA is a real accessibility cost and should wait until abuse is actually observed. |
| Submission retention / GDPR | `ip_address` is personal data with no expiry policy. A site should be able to say "delete enquiries after N days", and cannot yet. |
| Export (CSV) of enquiries | Straightforward; nothing has asked for it. |
| Per-form fields | Every form has name, email, subject, message. Custom fields need a field-definition table and a builder UI. |
| Image uploads in the editor | **Delivered in Group 8.** |
| Warning an author when sanitising removed something | `ContentSanitizer.isSafe()` exists for exactly this; no screen calls it. |

---

## 5. A routing flaw this group exposed

The admin shell claims `/admin`, and feature modules claim `/admin/pages`,
`/admin/blog`, `/admin/contact`. ColdBox prepends each module's entry point as
it loads, so the table ends up in reverse load order — and whichever sits higher
wins the URL.

`/admin/pages` and `/admin/blog` worked. `/admin/contact` resolved to the admin
shell and failed. Same code, different behaviour, decided by module load order.

`ModuleRouteOrderInterceptor` in Core now sorts module entry points
most-specific-first on `afterAspectsLoad`, once every module has registered. A
router should prefer the more specific pattern; this makes it do so.

Pages and Blog were working by luck before this. That is worth saying plainly.
