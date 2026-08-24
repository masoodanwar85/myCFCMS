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
| Size cap (10MB) | An upload filling the disk |

Verified against real files:

```
photo.png    accepted           120×80 recorded
evil.png     PHP wearing a .png -> "not a readable image, whatever it is named"
script.svg   rejected           -> "Files of type [svg] are not accepted"
big.png      11MB               -> "larger than the 10.0MB limit"
```

**SVG is deliberately excluded** even though it is an image. It is XML that can
carry script, and serving one from the site's own origin hands an uploader
cross-site scripting. That is a real loss — SVG is the right format for logos —
and the right way to allow it later is to sanitise it, not to add the extension.

### Deleting

The database row is removed before the file. A record pointing at a missing file
renders a broken image and is fixable; a file with no record is invisible and
never cleaned up.

---

## 2. The two image buttons

The toolbar carries two, because an author is answering one of two different
questions:

| Button | For |
| --- | --- |
| **Upload image** | A file on this machine, not yet in the library |
| **Media library** | Something already uploaded, chosen from a grid |

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

`GET /admin/media/browse` returns this site's images as JSON. It is an ordinary
`SecuredHandler` action behind `media.view` and scoped to `prc.currentSite`, so
it is subject to exactly the same tenant rules as the Media screen itself —
there is no second, looser path to the same rows. Documents are filtered out on
`mime_type`, because a PDF inserted as an `<img>` is a broken image.

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

## 4. What is implemented

- `media` table, `MediaService`, admin library with pagination, per-site storage.
- Core `/media/...` handler with tenant scoping, immutable caching and `nosniff`.
- Four media permissions, upload separated from delete.
- CKEditor image upload, with CSRF over a header.
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
| Media picker in the editor | The image button uploads; it cannot yet browse what is already in the library. |
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
