# Contact Forms and Rich Text Editing (Group 7)

Two things: a rich text editor for content, and the first module that accepts
input from people who are not signed in.

To build another module on the same shape, follow
[creating-a-module.md](../guides/creating-a-module.md) — it walks Contact
step by step.

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
| `contact_forms` | **One per site**, enforced in the service. The table is plural for historical reasons; see "One form per site" below. |
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

## One form per site

`contact_forms` was plural in the database and singular in practice for a long
time. `/contact` served the site's first active form **ordered by name**, and a
second form had no URL, no menu entry and no way to be chosen &mdash; the admin
let you create something you could not publish. Worse, the ordering meant
renaming a form could silently change which one a site served.

Contact is now what it always behaved like: **a site's enquiry form and its
settings**. `ContactService.createForm()` refuses a second, and
`getFormForSite()` returns the oldest active row by id &mdash; stable, and
meaning "the one you set up first" rather than "the one that sorts earliest".

A form with its own fields is a different thing and belongs to the **Forms**
module, which owns field definitions, its own submissions and its own `[form]`
shortcode. Splitting them keeps Contact small and stops the enquiry form growing
a builder it does not need.

Rows left over from the plural era are **not deleted by anything automatic** —
one holds a recipient address somebody configured and may hold enquiries, and
discarding that to tidy a data model would be the CMS losing a client's mail.
The admin lists them under "Other forms" with their enquiry counts so an
operator can move or remove them deliberately.

## Embedding the form

`[contact-form]` places the site's enquiry form in any page or post, so an
author can put it under the copy that explains it rather than linking away to a
bare URL. It takes no attributes.

Rendering goes through the site's theme, not markup in the shortcode.
`contact-form.cfm` and `contact-sent.cfm` already exist in every theme and a
client may have styled them; an embedded form that looked different from the one
at `/contact` would be a bug in waiting. The theme is passed `embedded`, so it
drops its own `<h1>` and wrapper &mdash; the page around it already has both.

### The round trip

An embedded form posts back to **the page it sits on**.
`ContactContentResolver.handleSubmission` claims that POST when it carries a
marker matching this site's form; the marker is what makes claiming another
module's path defensible, and without it the request is left alone.

With one form per site the marker can only *confirm or deny* &mdash; it can no
longer select between forms. That closes the hole where editing the hidden field
in the page source routed a message to a different recipient.

Both outcomes then answer with a redirect, and the state travels in flash:

| | |
|---|---|
| Sent, no thank-you page | Back to the same path; the shortcode renders the success message in place of the form |
| Sent, thank-you page set | Redirect to that path |
| Refused | Back to the same path, with the errors and what was typed |

The flash is keyed by form slug, so two forms on one page cannot show each
other's messages, and it is read exactly once &mdash; a success message that
survived into the next page view would tell a visitor they had sent something
they had not. Only the four form fields are flashed back: the CSRF token and the
reCAPTCHA response have no business in the session.

`/contact` is unchanged. There a refusal still re-renders the form in place with
a `422`, because that resolver owns the URL and can. An embedded form cannot
&mdash; the page belongs to Pages &mdash; so the difference is forced by who
owns the URL rather than chosen. A side effect is that an embedded refusal
cannot be re-posted by refreshing, which the `422` path still allows.

### The thank-you page

`thank_you_path` is optional and blank by default, which means "stay on the
page". It exists for one reason: advertising conversion tracking fires on a
**page being loaded**, and a message swapped in by the server produces no URL for
Google Ads or GA4 to see. A firm paying for clicks needs the redirect; a firm
that is not should not have to configure one.

Site-relative paths only, enforced in `ContactService.safeReturnPath()`. An open
redirect on a public form is how a phishing page borrows a client's domain: the
victim sees the firm's address in the link they were sent and lands somewhere
else. A bad value is stored as empty rather than refused &mdash; a form is not
worth failing to save over a mistyped path.

### Two bugs this closed

`findFormBySlug` did not filter on `is_active`, so a form somebody had switched
off still accepted submissions from anyone who posted its slug. `is_active` now
means what it says.

And the themes have always emitted the form's slug in a hidden field while
`/contact` ignored it on display and honoured it on submit &mdash; so a visitor
could edit it and route their message to a different recipient. With one form
per site the marker is only ever compared against that form, so there is nothing
left to select.

## 3. What is implemented

- CKEditor 5, self-hosted, on the page and post content forms.
- A CMS AntiSamy policy that preserves editor markup and still blocks script.
- `contact_forms` and `contact_submissions`, with composite tenant keys.
- `ContactService`, resolver, navigation provider and admin screens.
- `handleSubmission` on the resolver contract, and POST routing in Core.
- Three permissions, separating reading enquiries from configuring forms.
- `[contact-form]`, so the enquiry form can be embedded in a page or post, with
  an optional thank-you page for conversion tracking.
- 424 passing specs across Groups 1–7.

## 4. What is intentionally postponed

| Area | Why it waits |
| --- | --- |
| Email notification | Needs a mail layer. This is now the single biggest gap: it also blocks password reset and user invitations. |
| CAPTCHA | The honeypot and throttle handle ordinary spam. A CAPTCHA is a real accessibility cost and should wait until abuse is actually observed. |
| Submission retention / GDPR | `ip_address` is personal data with no expiry policy. A site should be able to say "delete enquiries after N days", and cannot yet. |
| Export (CSV) of enquiries | Straightforward; nothing has asked for it. |
| Per-form fields | The enquiry form is fixed: name, email, subject, message. Forms with author-defined fields are the **Forms** module's job, not Contact's. |
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
