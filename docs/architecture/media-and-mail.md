# Media Library and Mail (Group 8)

Two pieces of infrastructure the CMS could not ship a real client site without:
somewhere for images to live, and a way to send email.

---

## 1. Media

### Where files live, and why it costs a request

Uploads are stored **outside the webroot**, at `storage/media/{siteId}/{yyyy}/{mm}/`,
and served by a Core handler at `/media/...`.

Putting them under `public/` would have been faster and simpler. It would also
mean one site's uploads are reachable from every other site's domain, and that
any file which slipped past validation sits in a directory the web server will
happily execute. Neither is acceptable in a shared-database, shared-webroot
tenancy model.

The cost is one ColdFusion request per file. Filenames carry a random suffix and
never change, so responses are `immutable` with a one-year max-age and a browser
asks once — but **a busy public site should put a reverse proxy or CDN in front
of `/media/`**. That is a deployment change, not a code change: the handler sets
correct caching headers already.

The public URL carries no site id (`/media/2026/08/photo-a1b2c3d4.png`). The
handler scopes the lookup to the current tenant, so another site's domain gets a
404 for the same URL — the same answer an unknown file gets, so a 404 never
confirms that a file exists somewhere else.

### Accepting an upload

An upload endpoint is the classic route to getting an executable file onto a
server, so every part of what arrives is distrusted:

| Defence | What it stops |
| --- | --- |
| Stored outside the webroot | A file that defeats everything below still cannot be executed |
| **We** name the file, never the uploader | `../../`, null bytes, and shell characters have nowhere to go |
| Extension **allow-list** | A deny-list is a guess about what is dangerous; an allow-list states what is wanted |
| Content is verified, not trusted | An image must decode as one; a PDF must start with `%PDF` |
| Stored MIME type comes from our table | A browser obeys `Content-Type`; letting an uploader pick it is letting them pick how the file is interpreted |
| `X-Content-Type-Options: nosniff` | A browser second-guessing the type and running it as script |
| Non-images sent as `attachment` | A PDF opened inline can host script in some readers |
| Size cap, per kind | An upload filling the disk |

Verified against real files:

```
photo.png    accepted           120×80 recorded
evil.png     PHP wearing a .png -> "not a readable image, whatever it is named"
evil.pdf     HTML wearing a .pdf -> "not a PDF, whatever it is named"
rates.xlsx   accepted           PK\x03\x04 confirmed
script.svg   rejected           -> "Files of type [svg] are not accepted"
big.png      11MB               -> "larger than the 10.0MB limit for images"
```

**SVG is deliberately excluded** even though it is an image. It is XML that can
carry script, and serving one from the site's own origin hands an uploader
cross-site scripting. That is a real loss — SVG is the right format for logos —
and the right way to allow it later is to sanitise it, not to add the extension.

### Documents, and the `kind` column

The library holds two kinds of thing, and the difference runs through every
screen that touches it: `kind` is `image` or `document`.

It is a stored column rather than a `mime_type LIKE 'image/%'` test, because
"document" expressed as *not an image* starts quietly including a video the day
one can be uploaded. Each query is now a positive statement about what it wants,
and a third kind is a new value instead of a rewrite.

`kind` decides what a **picker lists** and how a **cell is drawn**. It does not
decide how a file is **served** — `isImage()`, reading the verified `mime_type`,
is still what `Media.cfc` asks before sending something inline. A row whose kind
somehow disagreed with its mime type would appear in the wrong tab; it would not
be served as the wrong type.

#### What is accepted, and what is not

| Kind | Extensions | Cap |
| --- | --- | --- |
| Image | `jpg` `jpeg` `png` `gif` `webp` | `maxImageBytes`, 10MB |
| Document | `pdf` `docx` `xlsx` `pptx` `csv` `txt` | `maxDocumentBytes`, 25MB |

Two caps because the two are not comparable: 10MB is generous for a photograph
and tight for a scanned forty-page contract.

Three things are deliberately absent:

- **`zip`** — a container for arbitrary files. Accepting one turns the client's
  own domain into somewhere a payload can be published and linked to, and no
  check on the archive says what a reader will do with its contents.
- **`doc`, `xls`, `ppt`** — macro-capable, and all three share the OLE2
  signature `D0CF11E0A1B11AE1`, so a `.xls` full of a macro-laden Word document
  passes any check the allow-list could make.
- **`svg`** — unchanged from Group 8: XML that can carry script.

#### How much verification is actually possible

Three tiers, and the docs should be honest about the third:

1. **An image must decode.** Not a prefix check — the file is handed to the
   image reader, so a `.png` full of PHP fails because it is not a picture.
2. **A signed document must start with its signature.** This catches the
   mislabelled file. It does *not* identify the format: `docx`, `xlsx` and
   `pptx` are all ZIP archives sharing one signature, so this proves "a ZIP
   container" and the extension decides which of the three it is served as.
   Proving more means opening the archive to look for `word/document.xml`,
   which needs ColdFusion's `zip` package — present on a full install, absent
   on the minimal one this is developed against, so it would turn a verified
   upload into an environment-dependent one.
3. **Plain text cannot be checked at all.** `csv` and `txt` have no signature;
   any bytes are a valid text file. What makes that acceptable is not the upload
   check but the serving policy — every non-image goes out as
   `Content-Disposition: attachment` with `nosniff`, so a `.txt` full of HTML is
   downloaded as text, never rendered as a page on the site's own origin.

Signatures are compared as **binary**. The original PDF check read the file
through a UTF-8 decoder and worked only because `%PDF` is ASCII; a ZIP's
`PK\x03\x04` carries control bytes that character decoding can substitute, and
the comparison would then fail on a perfectly good file.

### Linking a document: `[file]`

```
[file id="12"]Our terms of engagement[/file]
[file id="12"]
```

Renders a link carrying the label, the type and the size:

```html
<a class="file-link" href="/media/2026/10/terms-a1b2c3d4.pdf" data-ext="pdf">
    Our terms of engagement <span class="file-meta">PDF, 240.5 KB</span>
</a>
```

An author could write the `<a href>` by hand instead. The reason not to is next
year: the terms are reissued, the new file gets a new generated name, and every
page that linked the old one now points at a file that is gone — or still points
at last year's terms. Stored as an id, the label, type and size are read from
the library at render time, so replacing the file corrects every page that
links it.

With no label the link uses the item's **title**, falling back to the uploaded
filename — never the generated one, because nobody means to publish a link
reading `terms-a1b2c3d4.pdf`. Title is therefore the field the library card
offers for a document, where an image gets alt text.

The size sits in the link text rather than a `title` attribute on purpose: it
tells somebody on a metered connection what they are about to spend, and a
tooltip is invisible on a touchscreen.

`[file]` refuses an image — `[image]` renders those — and refuses an id
belonging to another site. Expansion happens *after* the sanitiser, so every
value it writes is escaped at the point it is written.

### Deleting

The database row is removed before the file. A record pointing at a missing file
renders a broken image and is fixable; a file with no record is invisible and
never cleaned up.

---

## 2. The editor's media buttons

The toolbar carries three, because an author is answering one of three
different questions:

| Button | For |
| --- | --- |
| **Upload image** | A file on this machine, not yet in the library |
| **Media library** | An image already uploaded, chosen from a grid |
| **Insert file** | A document to link, chosen the same way |

### Upload

CKEditor uploads straight into the library through `SimpleUploadAdapter`, so an
image an author drops into a page becomes an ordinary media item — visible in
the library, editable, deletable.

The endpoint returns `{ "url": "..." }`, or `{ "error": { "message": "..." } }`
which CKEditor shows to the author. Those messages are written for a person, not
a log.

**CSRF over a header.** The editor posts by script and has no form to carry a
token, so it sends `X-CSRF-Token`. `SecuredHandler` now accepts the token from
either place — same session token, same check, different transport. Verified: a
post without it gets `419` and stores nothing.

### Picking from the library

Without a picker, re-using one photograph across ten pages meant uploading it
ten times, leaving ten copies on disk and ten separate alt texts to maintain.

`GET /admin/media/browse?kind=image` returns this site's files of one kind as
JSON. It is an ordinary `SecuredHandler` action behind `media.view` and scoped to
`prc.currentSite`, so it is subject to exactly the same tenant rules as the Media
screen itself — there is no second, looser path to the same rows.

`kind` defaults to `image` rather than to everything, because every caller that
existed before documents did is inserting an `<img>` or filling an image field —
the editor's image button, the site logo, a page's featured image, a slide
background — and a PDF in any of those is a broken image. An unrecognised kind
matches nothing rather than falling through to the whole library: the value
arrives from a query string, and a `WHERE` clause that quietly drops away would
hand a picker every row it did not ask for.

`window.cmsPickMedia( { kind: "document" } )` opens the same dialog in document
mode, and any admin field can do the same with
`data-pick-media="fieldId" data-pick-kind="document"`. A document cell has no
thumbnail, so the type label fills that space at the same height — a grid of
mixed kinds does not jump — and the second line shows the size rather than the
alt text.

The picker itself is plain DOM styled by the admin stylesheet rather than a
CKEditor UI view, so it looks like the rest of the admin and does not have to
track the editor's own UI API. Insertion goes through the editor's `insertImage`
command, so the result is an ordinary image widget — resizable, captionable,
styleable.

Three states, all verified in a browser: images, an empty library, and a
failure. A lapsed session is the awkward one: it redirects to the sign-in page,
which `fetch` follows and reports as a perfectly good `200` of HTML. The picker
checks the content type and says the session expired, rather than showing the
author a JSON parse error.

### What the sanitiser does to editor output

Group 7's policy permitted `<img>` and `<figure class="image">`, and the
caption, alt text and image-style classes all survive. **The resize width did
not.** CKEditor writes it as `style="width:37.5%"`, the policy allowed `style`
on nothing at all, and so an author could resize an image, save, and watch it
silently spring back.

The policy now allows `style` on `figure` and `img` only, validated against
`<css-rules>` that permit nothing but `width` and `height` as a percentage or a
pixel count. What that refuses matters as much as what it keeps, and is specced:

```
position:fixed;top:0;left:0     -> position, top, left all dropped
background:url(javascript:...)  -> dropped
width:expression(alert(1))      -> dropped
<p style="width:50%">           -> style dropped; it is not an image
```

`style` is declared in `<common-attributes>` because AntiSamy requires any
attribute a tag names to exist there, but it is deliberately **not** in
`<global-tag-attributes>` — only the two tags that ask for it get it.

---

## 3. Mail

`MailService` in Core. The one thing it must never do is lose a message quietly,
so **every message is written to `mail_messages` before any attempt is made**.

Three modes, set by the `mailMode` core setting:

| Mode | Behaviour |
| --- | --- |
| `off` *(default)* | Record and stop |
| `log` | Record, and write the body to the log so a developer can read what a client would have received |
| `send` | Record and deliver |

The default is `off` because no SMTP is configured. Defaulting to `send` would
make every attempt fail instead of recording it for later.

**A caller never checks the mode.** It asks for a message to be sent and gets a
record back; whether that record says `sent` or `suppressed` is a deployment
question. Delivery failures are recorded, never thrown — a contact form must not
reject a visitor's message because SMTP is down.

Bodies can be a string or a rendered view (`emails/contactNotification`), and
the templates escape everything a visitor wrote.

Contact notifications now go through this, so `sendNotifications` finally means
something.

---

## `cfmail`, and why it lives in its own file

The mail tag is called from `_send.cfm`, an included template, not from a line
of cfscript in `MailService`. Two facts force that, and neither is obvious.

**`mail()` is not Adobe syntax.** The unprefixed tag-in-script form is Lucee and
BoxLang. Adobe ColdFusion does not resolve it and reports *"Variable MAIL is
undefined"* — which reads like a coding slip and sends you hunting for a
variable. `MailService` was written that way and so could never send on Adobe at
all, whatever the configuration said.

**`cfmail` is resolved at compile time.** ColdFusion 2021 and later ship
modular, and `mail` is not among the packages a minimal install includes. Put
`cfmail` directly in `MailService.cfc` on such an install and that whole
component fails to compile — WireBox cannot build it, every screen injecting it
breaks, and the symptom is an unrelated `Injector.InstanceNotFoundException`
naming some other component entirely.

Isolated in an included template, the same failure is an ordinary catchable
exception at the point of the include. One send is recorded as `failed` with a
usable reason; nothing else is affected.

`attributeCollection` is what makes the tag form workable. `cfmail()` in
cfscript rejects it, which would mean writing every attribute out twice — once
with a reply-to and once without. The *tag* accepts it.

The raw errors name neither mail nor packages, so `looksLikeMissingMailPackage()`
translates them into the sentence an operator needs. It is matched narrowly on
the message, because the engine reports it with no distinguishing type, and a
genuine SMTP failure must never be relabelled as a missing package.

### Four things must all be true

| | |
|---|---|
| `core.mailMode` | `send`. `log` writes the rendered message to `app/logs/app.log` instead — worth using first. |
| `core.mailFrom` | A real address. The default `no-reply@localhost` is rejected by most servers. |
| `<module>.sendNotifications` | Per module, false by default. When false nothing is even queued, so `mail_messages` stays empty — which is how to tell this gate from the others. |
| The ColdFusion mail package | `cfpm install mail`, then restart. Plus an SMTP server under Server Settings → Mail. |

`resources/tools/MailCheck.cfm` walks all four and reports which one stopped a
message.

### A note on the specs

`MailSpec` sets the mode it needs and restores the configured one afterwards. It
used to read the live setting, so it passed only while the application happened
to have mail switched off, and began failing the day somebody configured it —
reporting a fault in the mail layer when the only thing that had changed was a
config file.

## 4. What is implemented

- `media` table, `MediaService`, admin library with pagination, per-site storage.
- Core `/media/...` handler with tenant scoping, immutable caching and `nosniff`.
- Four media permissions, upload separated from delete.
- CKEditor image upload, with CSRF over a header.
- Documents: `kind` column, per-kind allow-lists and caps, binary signature
  checks, a document mode for the picker, an "Insert file" toolbar button and
  the `[file]` shortcode.
- `mail_messages`, `MailService`, three modes, view templates.
- Contact notifications wired to the mail layer.
- 491 passing specs across Groups 1-8.

## 5. What is intentionally postponed

| Area | Why it waits |
| --- | --- |
| **Password reset and invitations** | Now unblocked — the mail layer exists. This is the obvious next step, and until it lands an admin still sets passwords by hand. |
| Reverse proxy / CDN for `/media/` | A deployment change. The handler already sends the caching headers that make it worthwhile. |
| Image resizing and thumbnails | Full-size images are served to every context, including a 7rem grid tile. The first thing to add when bandwidth matters. |
| SVG support | Needs an SVG-specific sanitiser, not an extra line in the allow-list. |
| Office format identification | A `docx` check confirms a ZIP container, not that it is a Word document. Needs the `zip` package to go further; see the verification tiers above. |
| Documents in the sitemap or search | A PDF is reachable by link only. Nothing lists the library publicly. |
| "Replace this file" | Replacing a document means uploading a new one and repointing the `[file]` id. The shortcode makes that one edit instead of many, but there is no in-place replace. |
| "Where is this used?" | Deleting a file gives no warning that a page still points at it. |
| Storage quotas per site | Usage is shown; nothing enforces a limit. |
| Retrying failed mail | Failures are recorded but never retried; there is no queue runner. |
| A mail log screen in the admin | `MailService.getMessages()` exists; nothing renders it. |

---

## 6. Two ColdFusion traps worth recording

**`content file=` is not valid script syntax.** It parses as a reference to an
undefined variable named `content`. The script form is `cfcontent( file=..., type=... )`.

**ColdBox strips known extensions from URLs.** `pdf`, `html`, `xml`, `json`,
`rss` and `cfm` are treated as requested *formats* and removed from the routed
path — so `/media/2026/08/notes.pdf` arrived without its extension and could not
be found, while `.png` worked. Extension detection is now switched off in
`app/config/Router.cfc`: nothing here uses it, and a CMS serving arbitrary file
paths and page slugs cannot afford silent truncation. A page slug ending in
`.html` would have been mangled the same way.
