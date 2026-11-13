# myCFCMS MCP server

Lets an AI agent manage myCFCMS sites — create and edit pages, apply layouts,
upload media, audit SEO — through the CMS's REST API.

It talks to the CMS **only over `/api/v1`**. It opens no database connection and
never will. Two consequences worth stating up front:

- it can do nothing an operator could not do with a token and `curl`, and
- every write it makes is recorded in the CMS's own `api_change_log`, with a
  before-and-after snapshot, readable at `/admin/api-activity`.

## What it will not do

| | |
| --- | --- |
| Delete anything | No tool exists. `pages.delete` and `media.delete` are withheld from the `agent` role, so one could not work |
| Unpublish | Deliberately absent. The agent can put content up with a human's confirmation and can never take it down |
| Publish without confirmation | `publish_page` always needs `confirm: true` — including for a page it created a moment ago |
| Edit a live page without confirmation | `update_page`, `set_seo_fields` and `apply_layout` all refuse on a page that is published **or scheduled** |
| Guess which site you meant | Every write requires an explicit `site` |
| Upload from anywhere on disk | Paths must resolve inside `CMS_UPLOAD_ROOT` |

**These are agent guard rails, not security.** `pages.update` and
`pages.publish` are ordinary API permissions, so anyone holding the token can
`curl` straight past all of it. What covers that gap is the change log: the
write is recorded whichever route it took.

## Setup

### 1. A user and a token, per site

A myCFCMS token is bound to the site it was issued for — present it against
another tenant's domain and the API answers `403 wrong_site`. So each site needs
its own token:

1. `/admin/users` → create a user, assign the **Agent** role
2. `/admin/api-tokens` → issue a token for that user, and copy it. It is shown
   once and stored hashed; nothing can recover it afterwards

The Agent role carries exactly nine permissions: `site.view`,
`pages.view/create/update/publish`, `media.view/upload`, `seo.view/run`. It
cannot delete, cannot write raw HTML, and cannot read its own audit trail.

### 2. Install and build

```bash
cd mcp
npm install
npm run build
```

### 3. Configure

```bash
cp .env.example .env
```

| Variable | |
| --- | --- |
| `CMS_SITE_<NAME>_URL` | That site's origin. `<NAME>` is what you say in a prompt |
| `CMS_SITE_<NAME>_TOKEN` | That site's token |
| `CMS_DEFAULT_SITE` | Which site read-only tools use when a call names none. Optional; unnecessary with one site. Writes never default |
| `CMS_TIMEOUT_MS` | Per-request timeout, default `30000`. A site audit is polled, so this need not cover a crawl |
| `CMS_UPLOAD_ROOT` | `upload_media` refuses paths outside this. Defaults to the working directory |

`mcp/.env` is gitignored. Keep it that way — a token committed once stays in the
history for ever.

#### The URL is the site's own origin, not a shared base URL

Tenancy is resolved from the `Host` header, so the obvious design is one address
plus a per-site `Host` override. Node's `fetch` will not do it: `Host` is a
forbidden header in undici and is dropped **silently**, so the request would
reach whichever tenant answers on that address with no error to say so.

A URL per site sidesteps it, because the URL *is* the host. Locally that means
hosts entries:

```
# /etc/hosts
127.0.0.1  willcreator.test  cleverminds.test
```

```
CMS_SITE_WILLCREATOR_URL=http://willcreator.test:58988
```

and registering those hostnames as domains on the sites. `box server info`
reports the port. The limitation this leaves: a site whose real domain is not
resolvable from where this server runs cannot be reached at all.

### 4. Connect it to Claude

```bash
claude mcp add mycfcms --env-file ./mcp/.env -- node /absolute/path/to/myCFCMS/mcp/dist/index.js
```

Or by hand, in your MCP client's config:

```json
{
  "mcpServers": {
    "mycfcms": {
      "command": "node",
      "args": ["/absolute/path/to/myCFCMS/mcp/dist/index.js"],
      "env": {
        "CMS_SITE_WILLCREATOR_URL": "https://willcreator.com.au",
        "CMS_SITE_WILLCREATOR_TOKEN": "cms_...",
        "CMS_SITE_CLEVERMINDS_URL": "https://cleverminds.com.au",
        "CMS_SITE_CLEVERMINDS_TOKEN": "cms_..."
      }
    }
  }
}
```

An absolute path, because the client starts the server with an unpredictable
working directory. On startup it prints the sites it found **to stderr** —
stdout is the protocol stream, and one stray line on it makes the server
unparseable.

## Talking to it

Name the site in the sentence; you do not need to mention tools.

> *"List the draft pages on cleverminds."*
> *"On willcreator, create a page called 'Probate in Victoria' with a draft intro."*
> *"Audit /about on cleverminds and fix the meta description."*
> *"Which pages on willcreator link to something that 404s?"*

Writes come back refused until you confirm, and the refusal says what it was
about to do and where:

> `publish_page` refused: About to make "Probate in Victoria" (/probate-in-victoria)
> on **willcreator** publicly visible. Pass confirm: true to publish it.

Then: *"Yes, publish it."*

## Tools

| Tool | Site | |
| --- | --- | --- |
| `list_pages` | optional | Every page, with paths, parents and status. No bodies |
| `get_page` | optional | One page in full. Read before editing |
| `create_page` | **required** | Creates a **draft**. Never publishes |
| `update_page` | **required** | Only the fields you pass. Confirm if live |
| `set_seo_fields` | **required** | Canonical, robots, Open Graph, sitemap, featured image. Confirm if live |
| `publish_page` | **required** | **Always** needs `confirm: true` |
| `list_layouts` | optional | Templates per theme, active theme marked |
| `get_layout` | optional | Which theme offers one layout, and whether it is applicable |
| `apply_layout` | **required** | Validates the name against the active theme first |
| `list_media` | optional | The library, paged, with the `/media/...` urls |
| `upload_media` | **required** | From a local path inside the upload root |
| `audit_page_seo` | optional | One live URL, now. Title, description, h1, headings, alt, canonical, noindex, structured data, links |
| `audit_site_seo` | optional | Crawls every public URL. Runs in the background; this polls |
| `find_broken_links` | optional | Internal 404s and redirects, attributed to the page containing the link |

`list_media` is not in the original brief. It is here because an agent setting
`ogImage` or `featuredImage` on an existing page needs to find a URL it did not
upload itself in the same conversation.

### Two behaviours worth knowing

**`apply_layout` validates before writing.** `PageService.safeTemplateName()`
only strips characters — it does not check the template exists, and the front
controller silently falls back to the default view at render time. So the API
answers `200` for an unknown template and renders nothing different. This tool
checks the active theme's own list first, because reporting that as success
would be lying to an agent that will not look again.

**`set_seo_fields` reports what was stored, not what you sent.** The CMS
validates and corrects: an unknown `ogType` becomes `website`, a sitemap
priority is clamped, a canonical is normalised, and `javascript:` is refused
outright with a 422. Echoing the request would misreport the result.

## Tests

```bash
npm test
```

44 tests, no credentials needed. Configuration and site routing, the
confirmation gates, and a real stdio handshake that starts the server and checks
which tools exist and which demand a site.

Six of them exercise the HTTP client against a running CMS, which needs no token
because an unauthenticated request still returns the real error envelope:

```bash
MCP_CMS_URL=http://127.0.0.1:58988 npm test
```

The full lifecycle against a live site needs a token, and is **opt-in** so a
test run can never write to a client's website by accident:

```bash
npm run build
MCP_LIVE_SITE=local MCP_LIVE_ALLOW_WRITES=true npx vitest run live
```

It creates pages slugged `zzt-mcp-...` and deletes nothing — there is no delete
tool — so a failed run leaves a draft for you to look at.

## Troubleshooting

| | |
| --- | --- |
| `Configuration error: No sites configured` | `CMS_SITE_<NAME>_URL` and `_TOKEN` must both be set |
| `401 unauthenticated: That token is not valid` | Revoked, expired, mistyped, or the user was deactivated |
| `403 wrong_site` | The token belongs to a different site than the URL resolves to |
| `403 forbidden: ... does not carry the [x] permission` | The token's user is missing the Agent role |
| `404 unknown_site` | No `site_domains` row matches the hostname in the URL |
| `0 unreachable` | Wrong port, server down, or a hostname that does not resolve from here |
| Client shows no tools | Run `npm run build`; the config must point at `dist/index.js`, absolute |
