# Theme assets and per-site branding

Where a logo, a stylesheet and a font belong when one application serves many
sites. The short answer is that they belong in three different places, because
they are three different things.

| | Belongs to | Lives in | Served by |
|---|---|---|---|
| Logo, brand images, PDFs | one **site** | `storage/media/<siteId>/` | ColdFusion, at `/media/...` |
| CSS, JS, fonts, theme images | one **theme** | `public/assets/themes/<slug>/` | the web server, directly |
| Colours and font stacks | one **site** | `site_settings` | inlined into the page |

## 1. Uploads belong to a site

A logo is not part of a theme. Two clients on the same theme have different
logos, so it is tenant data and goes through the media library like any other
upload.

`MediaService` stores under `storage/media/<siteId>/YYYY/MM/`, outside the
webroot, and `core:Media.serve` hands files out scoped to the resolving tenant:
site A cannot fetch site B's file even by guessing the path, and an upload that
slipped past validation sits somewhere the web server will not execute.

The cost is a ColdFusion request per file. Filenames carry a random suffix and
never change, so the response is `immutable` and a browser asks once — but a
busy public site should put a CDN in front of `/media/`.

## 2. Static assets belong to a theme

```
public/assets/themes/willcreator/css/theme.css
public/assets/themes/willcreator/js/theme.js
public/assets/themes/willcreator/fonts/…
```

Build the URL through the theme rather than hard-coding it:

```cfml
<link rel="stylesheet" href="#args.theme.assetUrl( 'css/theme.css' )#">
```

`args.theme` is passed to every layout **and** every view, so a view that needs
a background image builds its URL the same way.

### Why not beside the templates

`themes/<slug>/` holds `layouts/main.cfm` and `views/*.cfm` and is deliberately
**outside** the webroot. Exposing that directory to the web server would make
`layouts/main.cfm` directly requestable — and behind mod_jk, whose mounts match
on `.cfm`, executable. A layout invoked with no `args` is at best an error page
and at worst an information leak.

So the split is not arbitrary: templates out, static files in. `assetUrl()` is
the single place that knows about it.

### Don't hotlink

The willcreator theme used to load its logo from
`https://willcreator.com.au/sites/default/themes/…`. That works right up until
`willcreator.com.au` is pointed at this server, at which point the URL resolves
to this CMS, which has no such path, and every page loses its logo at the exact
moment of cutover.

The same applies to a CDN copy of jQuery or a Google Fonts stylesheet: they make
a client's site depend on a third party being up, and they tell that third party
about every visitor.

## 3. Colours and fonts belong to a site

Two law firms on one theme differ by about fifteen lines — a brand colour, an
accent, a heading font. That is a settings form, not a per-site stylesheet with
an upload UI and a cache-busting story.

**Settings → Branding** writes five values. `SiteBrandingService` turns them
into custom properties on `:root`, emitted after the theme's stylesheet so they
win:

```css
:root{--brand-primary: #0f2a4a;--brand-accent: #c19b43;}
```

A theme opts in by treating them as overrides of its own defaults:

```css
:root {
    --eucalypt: var(--brand-primary, #3E5C50);
    --brass:    var(--brand-accent,  #B08A4F);
    --display:  var(--brand-font-heading, "Fraunces", Georgia, serif);
}
```

A site that has set nothing produces no declarations at all, and the theme's
fallbacks stand. Nothing has to be configured for a theme to work.

### These values are untrusted

They are typed into a form by a client and end up inside a `<style>` block,
where a stray `}` ends the rule and everything after it is new CSS. Colours must
be hex literals; font stacks may contain only family names, quotes and commas —
no semicolons, braces or parentheses, so no `url(`.

Validation runs on the way in **and** again on the way out. A row can reach
`site_settings` from a migration, a seed or a direct `UPDATE`; the read path
does not assume whatever wrote it went through the service. A stored value that
would not pass validation today is dropped rather than rendered.

The logo address is checked the same way: site-relative or explicit `http(s)`,
with the *whole* string constrained rather than just the prefix — anchoring only
the start would accept `https://x" onerror="alert(1)`.

## Adding a theme

```bash
cp -R themes/default themes/acme
mkdir -p public/assets/themes/acme/css
```

Set `name` in `themes/acme/theme.json`, put your CSS in
`public/assets/themes/acme/css/theme.css`, link it with `assetUrl()`, and make
your colour and font tokens defer to `--brand-*`. Then select it when
provisioning, or from **Settings → Theme**.

Two directories per theme is the one wrinkle in the arrangement. It buys static
assets served without touching ColdFusion, and templates that cannot be reached
over HTTP.

## Deployment

`public/assets/` is ordinary static content — no mod_jk mount, no ColdFusion.
Worth a cache header in the vhost, since the files are versioned by deploy
rather than by filename:

```apache
<Location /assets/>
    Header set Cache-Control "public, max-age=3600"
</Location>
```

Keep it modest, or a stylesheet change will not reach browsers until the header
expires.
