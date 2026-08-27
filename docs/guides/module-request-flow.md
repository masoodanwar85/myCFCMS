# How a module request flows

Two URLs, two completely different paths after the router.

Contact is the example:

| Side | Example | Who handles it |
| --- | --- | --- |
| Admin | `GET /admin/contact` | Contact's own `Admin.cfc` |
| Frontend | `GET /contact` | Core's `Frontend.cfc`, which *asks* Contact |

Your module does not add a line to `config/Router.cfc` for either of these.

---

## Both sides start the same way

Every request, admin or public:

```
1. Browser hits https://client.com/...
2. public/Application.cfc  →  ColdBox
3. TenantInterceptor.preProcess
      Host header  →  Site  →  TenantContext
      prc.currentSite is now set
4. Router matches a route
```

If the host is not an active domain of an active site, there is no tenant.
Admin then refuses (no site to sign in against). Frontend returns Core's
plain 404, with no theme.

From step 4 the two sides split.

---

## Admin: `GET /admin/contact`

A signed-in user opens Enquiries.

```
GET https://client.com/admin/contact
        |
        v
   [same 1–3 as above]
        |
        v
4. Router
   Contact's entryPoint is "admin/contact".
   That prefix is more specific than the admin shell's "admin",
   so this route wins (ModuleRouteOrderInterceptor sorted them).

   Pattern  /:action?/:id?   on handler Admin
   →  contact:Admin.index
        |
        v
5. SecuredHandler.preHandler     (Core, not Contact)
   Contact's Admin.cfc extends this. It runs before index().
        |
        +-- no tenant            →  unknown-domain page
        +-- not signed in        →  redirect /admin/login
        +-- POST without CSRF    →  expired-token page
        +-- missing permission   →  403 forbidden
        |
        sets:
          prc.currentSite
          prc.currentUser
          prc.csrfToken
          prc.adminNav
          layout = core/layouts/Admin.cfm
        |
        v
6. contact.handlers.Admin.index
   Reads prc.currentSite.getId().
   Calls ContactService.getSubmissions(siteId).
   event.setView( "admin/index", module = "contact" )
        |
        v
7. Render
   Body : app/modules/contact/views/admin/index.cfm
   Wrap : app/modules/core/layouts/Admin.cfm
          (top bar, nav filtered by this user's permissions)
        |
        v
8. HTML
```

### What each file does on this request

| File | Role |
| --- | --- |
| `app/modules/core/interceptors/TenantInterceptor.cfc` | Site from Host |
| `app/modules/contact/ModuleConfig.cfc` | `entryPoint = "admin/contact"` and the Admin route |
| `app/modules/core/models/security/SecuredHandler.cfc` | Sign-in, CSRF, `contact.view` |
| `app/modules/contact/handlers/Admin.cfc` | `index()` — load this site's enquiries |
| `app/modules/contact/models/ContactService.cfc` | Use case, no HTTP, no permission check |
| `app/modules/contact/views/admin/index.cfm` | The table |
| `app/modules/core/layouts/Admin.cfm` | Chrome around it |

The admin module is **not** on this path. It owns `/admin`, `/admin/login`,
users, roles, settings. Contact owns `/admin/contact`.

### Admin POST — same path, one extra check

Example: mark an enquiry as spam.

```
POST https://client.com/admin/contact/status/12
     csrfToken=...  to=spam
        |
        v
   [steps 1–5 identical]
   preHandler sees POST → verifies csrfToken
   permission for action "status" is contact.view
        |
        v
6. Admin.status
   requireSiteSubmission(12, prc)
        -- missing, or site_id != this site  →  Admin.NotFoundHere  →  404
   ContactService.setStatus(12, "spam")
   return done( "/admin/contact", "Enquiry updated." )
        |
        v
7. Redirect to GET /admin/contact
   Flash message shown in the layout
```

A state change is always POST + CSRF + `done()`. Never a GET link.

### Where an admin request can stop

```
no tenant          →  core:Security.unknownDomain
not signed in      →  302 /admin/login
bad CSRF           →  core:Security.expired
no permission      →  core:Security.forbidden     (403, action never runs)
unknown / wrong-site id  →  Admin.NotFoundHere    (404 inside admin chrome)
```

`index()` never runs in those cases. `overrideEvent()` sends the request to a
Core security screen instead.

---

## Frontend: `GET /contact`

A visitor opens the public form.

```
GET https://client.com/contact
        |
        v
   [same 1–3 as above]
        |
        v
4. Router
   /admin...  already claimed, this is not one of those.
   /media/... no.
   /          no — that is only the empty path.
   /:path*    yes.  path = "contact"
   →  core:Frontend.index
        |
        v
5. Frontend.index                         (Core)
   No tenant  →  Core 404, no theme. Stop.

   Theme = this site's theme (or "default").

   GET, so skip submissions.
        |
        v
6. ContentResolverRegistry.resolve(siteId, "contact")
   Asks each resolver, lowest priority first:
        BlogContentResolver        50   "blog"?  no → return
        ContactContentResolver     60   "contact"? yes
        PageContentResolver       100   never asked
        |
        v
7. ContactContentResolver.resolveContent(siteId, "contact")
   No active form for this site  →  return nothing
        →  registry continues, Pages may serve a /contact page
        →  or a themed 404

   Has a form  →  return {
        view   : "contact-form",
        args   : { form, csrfToken, honeypotField, action, errors, values },
        title  : "Contact us",
        statusCode : 200
   }
        |
        v
8. Frontend renders
   ThemeService.renderView( theme, "contact-form", args )
        →  themes/{slug}/views/contact-form.cfm

   NavigationService.getNavigationFor(siteId)
        →  curated menu, or every SiteNavigationProvider
           (Contact contributes "Contact us" → /contact)

   ThemeService.renderLayout( theme, body, { site, title, navigation, seo, ... } )
        →  themes/{slug}/layouts/main.cfm
        |
        v
9. HTML
```

### What each file does on this request

| File | Role |
| --- | --- |
| `app/config/Router.cfc` | Catch-all `/:path*` → `core:Frontend.index` |
| `app/modules/core/handlers/Frontend.cfc` | Front controller. Knows nothing about Contact. |
| `app/modules/core/models/routing/ContentResolverRegistry.cfc` | Asks resolvers |
| `app/modules/contact/models/ContactContentResolver.cfc` | "Yes, this path is mine" |
| `app/modules/contact/models/ContactService.cfc` | Load the form |
| `themes/default/views/contact-form.cfm` | The form HTML |
| `themes/default/layouts/main.cfm` | Site chrome |
| `app/modules/contact/models/ContactNavigationProvider.cfc` | Menu entry (asked on *every* public page, not only this one) |

Contact has **no public handler**. There is no `contact.handlers.Frontend`.
The module answers a question Core asks.

### Frontend POST — still `Frontend.index`, then the resolver

A visitor submits the form.

```
POST https://client.com/contact
     csrfToken=...  name=...  email=...  message=...
        |
        v
   [steps 1–5 identical, still core:Frontend.index]
        |
        v
6. Frontend sees POST
   ContentResolverRegistry.resolveSubmission(siteId, "contact", rc)
   Skips resolvers that have no handleSubmission.
   Contact has one.
        |
        v
7. ContactContentResolver.handleSubmission(siteId, "contact", formData)
        |
        +-- wrong path / no form     →  return nothing (not ours)
        +-- bad CSRF                 →  form again, 422, nothing stored
        +-- honeypot filled          →  { redirectTo: "/contact/thank-you" }
                                       store nothing
        +-- validation errors        →  form again, 422, values replayed
        +-- throttle                 →  form again, 422
        +-- ok                       →  ContactService.submit(...)
                                       { redirectTo: "/contact/thank-you" }
        |
        v
8a. redirectTo set
    Frontend.relocate( "/contact/thank-you" )
    Browser GET /contact/thank-you  →  back to the GET flow
    Resolver returns view "contact-sent"

8b. no redirect (errors)
    Frontend renders the returned view (contact-form) at 422
    Same theme wrap as GET
```

The POST never hits `handlers/Admin.cfc`. Admin is a different entry point.

---

## Side by side

Same module, two doors.

```
                    Host → TenantInterceptor → Router
                                    |
                    +---------------+---------------+
                    |                               |
            prefix /admin/contact            everything else
                    |                               |
            contact:Admin.*                  core:Frontend.index
                    |                               |
            SecuredHandler                   ContentResolverRegistry
            (login, CSRF, permission)               |
                    |                        ContactContentResolver
            ContactService                          |
                    |                        ContactService
            views/admin/*.cfm                       |
            + core Admin layout              themes/.../contact-form.cfm
                                             + theme layout
```

| | Admin | Frontend |
| --- | --- | --- |
| Route | Module entry point `admin/contact` | App catch-all `/:path*` |
| Handler | `contact.handlers.Admin` | `core.handlers.Frontend` |
| Auth | Required | None |
| Permission | `contact.view` / `manage` / … | None |
| Layout | `core/layouts/Admin.cfm` | `themes/{slug}/layouts/main.cfm` |
| Body | `app/modules/contact/views/admin/*.cfm` | `themes/{slug}/views/contact-form.cfm` |
| Tenant data | `prc.currentSite.getId()` in the handler | `siteId` passed into the resolver |
| POST | Same handler action, then `done()` redirect | Resolver `handleSubmission`, then `redirectTo` |

---

## Follow one value through

A visitor types "Hello" and sends the form. Staff then open it.

```
POST /contact  message=Hello
        Frontend.index
        ContactContentResolver.handleSubmission
        ContactService.submit
        ContactRepository.insert  →  contact_submissions row, this site_id

GET /admin/contact
        contact:Admin.index
        SecuredHandler checks contact.view
        ContactService.getSubmissions( this site_id )
        views/admin/index.cfm  shows "Hello"
```

Same service, same table, two request paths. The service never knows which
path called it.

---

## What your module must provide for each path

For the **admin** path to work:

1. `this.entryPoint = "admin/{name}"` and a route to `Admin`
2. `handlers/Admin.cfc` extending `SecuredHandler`
3. `views/admin/*.cfm`
4. `AdminNavigationRegistry.register( href = "/admin/{name}", ... )`

For the **frontend** path to work:

1. A content resolver with `resolveContent(siteId, path)`
2. `ContentResolverRegistry.register( ... )` in `onLoad`
3. A theme view for every `view` name you return
4. `handleSubmission` only if visitors POST
5. A navigation provider only if the public menu should link here

Create those files with [creating-a-module.md](creating-a-module.md).
