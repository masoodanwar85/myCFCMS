# Admin, Authentication and the Request Boundary (Group 5)

The screens that make everything built so far usable — and the point at which
authentication (deferred from Group 2) and permission enforcement (deferred from
Groups 2 and 3) finally land.

Read [access-control.md](access-control.md) and
[routing-and-themes.md](routing-and-themes.md) first.

---

## 1. Where the admin lives

`/admin` **on each tenant's own domain**. A client's staff sign in at
`client.com/admin`; a platform super admin can sign in on any client's domain.

There is no separate central admin host, because the tenant is already resolved
from the domain (Group 1) and a second way to identify one would be a second
thing to keep in step. The `/admin` prefix is claimed by the admin module's
entry point, which ColdBox **prepends** to the routing table — so it is matched
ahead of Group 4's public catch-all.

---

## 2. Authentication

`AuthenticationService` in Core. Group 2 stopped at "does this password match
this hash?"; carrying an identity across requests needed the request boundary
this group introduces.

A session records **both** who signed in and **which site** they signed in at,
and both are re-checked on every request:

```
getCurrentUser()
    |
    +-- no session key           -> null
    +-- no tenant resolved       -> null
    +-- session site != tenant   -> log out, null   <-- a session cannot be
    +-- account gone/deactivated -> log out, null       carried between tenants
    +-- user no longer of site   -> log out, null
    |
   the user
```

Other decisions worth naming:

**Every sign-in failure raises the same error with the same message.**
Distinguishing "no such account" from "wrong password" would turn the sign-in
form into a way of discovering who has an account on a client's site.

**A site's own users are looked up before super admins**, so an admin can sign
in on any client's domain without shadowing that client's own accounts.

**The session id is rotated on sign-in and sign-out**, so a session id captured
before sign-in is not still valid after it.

**Cookies are host-scoped, not domain-scoped.** `this.setDomainCookies` is now
`false`: with domain-level cookies, a session set on one subdomain tenant would
be sent to another.

---

## 3. The request boundary

`core.models.security.SecuredHandler` is where Groups 2 and 3's deliberate
decision — keep permission checks *out* of the services, so CLI tasks and
migrations can call them — gets paid off. Every admin screen runs through one
`preHandler`.

Handlers declare what each action needs:

```cfc
component extends="core.models.security.SecuredHandler" {

    variables.permissions = {
        "index"   : "pages.view",
        "create"  : "pages.create",
        "publish" : "pages.publish",
        "$every"  : "pages.view"     // fallback for anything unlisted
    };
}
```

**An action with no declared permission and no `$every` fallback is refused, not
allowed.** Forgetting to declare must fail closed. A handler that genuinely
means "any signed-in user" says so explicitly through `openActions`.

The base handler lives in **Core**, not in the admin module, so any module can
secure its own screens by extending it. Pages does exactly that and depends on
Core alone.

### The bug this boundary had, and why the specs pin it

The first version called `event.noExecution()` to refuse a request. That does
not work: ColdBox's `Controller.runEvent()` calls `preHandler` and then invokes
the action **without consulting that flag**. The result was a `403` response
whose body was the very page the user was not allowed to see.

The mechanism that does work is `event.overrideEvent()`. The Controller
re-resolves the handler after `preHandler` when the event has changed, so
execution lands on `core:Security.forbidden` instead of the protected action.

`AdminSecuritySpec` asserts not just the status code but that the refused
screen's content is **absent** — because a 403 with the content in it looks
correct from the outside.

---

## 4. CSRF

The admin runs on the same domain a client's visitors browse, and its forms
change data with a session cookie the browser attaches automatically. Without a
token, any page on the internet could post to them on a signed-in user's behalf.

`CsrfService` issues one token per session, rotated on sign-in and sign-out.
Per-form tokens would be stronger and would break the back button and multiple
tabs — a poor trade for an admin UI.

Verification is a **constant-time** comparison, so a token cannot be discovered
a character at a time by timing the response.

Every `POST`/`PUT`/`PATCH`/`DELETE` through `SecuredHandler` is checked. The
sign-in form is a public action, so it checks its own token explicitly.

---

## 5. Modules contribute their own admin

The admin shell carries no knowledge of Pages. Same principle as Group 4's
content resolvers:

```cfc
// app/modules/pages/ModuleConfig.cfc
this.entryPoint = "admin/pages";

function onLoad(){
    wirebox.getInstance( "AdminNavigationRegistry@core" )
           .register( label = "Pages", href = "/admin/pages",
                      permission = "pages.view", order = 30 );
}
```

The Pages module owns `app/modules/pages/handlers/Admin.cfc` and its own views.
Installing or removing the module adds or removes both its screens **and** its
navigation entry, with no change to the admin.

**Navigation is filtered by the same authorisation service that guards the
screens**, so a link never appears that would be refused when followed.

### Grouping

A flat bar stopped scaling at about eight sections and would get worse with
every module installed. A section may name a `group`:

| Group | Sections |
| --- | --- |
| *(top level)* | Dashboard, Settings, API |
| **CMS** | Pages, Menus, Media |
| **Modules** | Blog, Enquiries — and anything else installed |
| **Access** | Users, Roles |

Settings and API stay top level deliberately: both are site configuration rather
than a category of screens, and a menu holding one item each would turn one
click into two.

A group's position is the **lowest `order` among its members**, not a number
registered separately. That keeps one ordering scheme instead of two, and means
a module cannot reposition a whole group by picking a low number — only take a
place within it.

**A group disappears entirely when the user may reach nothing inside it.** An
empty "Access" menu names exactly what exists and says you are not allowed near
it, which is worse than not showing it. An editor sees `Dashboard · Access ·
Settings` and no hint that a CMS group exists.

The menus are `<details>`/`<summary>` rather than CSS hover dropdowns: they open
on click or Enter, close on Escape, and are reachable from the keyboard without
a line of script. A hover menu is none of those things on a touch screen. About
ten lines of progressive JavaScript close a menu when attention moves elsewhere;
without it they still work, they just need a second click to dismiss.

The admin module's routes are declared per handler rather than as a
`/:handler/:action?` catch-all — a catch-all would claim `/admin/pages` before
the Pages module's own entry point could, and which won would depend on module
load order.

---

## 5a. The shell's layout

`core/layouts/Admin.cfm` renders a **dark top bar** over a centred 1200px
column, with `core/layouts/_styles.cfm` holding the whole design language for
both the admin and the sign-in page. Nothing else styles the admin, so a change
lands in one file.

The bar carries the brand, the permission-filtered navigation (current section
highlighted, with room for a count badge), the current site, the signed-in user,
and log out. Lists share one vocabulary:

| Class | Used for |
| --- | --- |
| `.adm-toolbar` | The row above a list: primary action on the left, `.adm-count` pushed right |
| `.pill.on` / `.pill.off` | Published/draft, active/inactive — as a `<button>` where it is also the control |
| `.ico` / `.ico.danger` | Small outlined row actions: Edit, Set home, Delete |
| `tr.is-off` | A row that is not live, dimmed |
| `.btn.secondary.is-current` | The selected filter in a toolbar group |

**A state change is never a link.** Publish, unpublish, activate and delete are
`POST` forms carrying a CSRF token, styled to look like the pills and buttons
around them. They read as one-click controls but cannot be fired by a
prefetcher, a crawler, or an `<img src>` on another site.

---

## 6. Screens

| Screen | Permissions |
| --- | --- |
| Dashboard | any signed-in user; contents filtered per permission |
| Pages *(Pages module)* | `pages.view` / `create` / `update` / `publish` / `delete` |
| Users | `users.view` / `create` / `update` / `delete` |
| Roles | `roles.view` / `create` / `update` / `delete` |
| Settings | `site.view`, `site.update`, `site.settings.manage`, `site.domains.manage` |

Three separate permissions guard the Settings screen because the changes carry
very different risk: editing a name is routine, removing the last active domain
takes the site offline.

Guards against locking yourself out, each of which is a real way to strand a
site:

- You cannot delete your own user account.
- You cannot delete a role you currently hold.
- A site must keep at least one domain, and at least one **active** domain.
- Setting a site to `inactive` requires ticking a confirmation.

A user id in a URL is always checked against the current site before anything is
done with it — an id is a guess anyone can make, and Group 2's isolation
guarantees would mean nothing if a handler acted on one without asking whose it
is. Super admins are never editable from a tenant's admin.

---

## 7. When a record is not there

Every admin handler guards an id from the URL against the current site and
throws `Admin.NotFoundHere`. Nothing caught it, so tampering with an id — or
following a link to something since deleted — returned a **500 with a full
stack trace**, describing the application's internals to anyone who tried.

`SecuredHandler.onError` now turns exactly that type into a clean 404 inside the
admin chrome. Everything else is rethrown untouched, so genuine faults still
reach the framework's exception handling and the log rather than hiding behind
a friendly page.

Worth recording, because it cost time: the first version used `rethrow`, which
is **only valid inside a catch block**. In `onError` there is no active catch,
so it raised an error of its own and turned every fault into the 500 it was
meant to prevent. `throw( object = e )` rethrows anywhere.

## 8. Bounded lists

Two of the admin lists were unbounded and one was silently truncated:

| Screen | Was | Now |
| --- | --- | --- |
| Enquiries | capped at 100, **nothing to reach the rest** | paged, 25 per page |
| Blog posts | fetched **every post** a site had written | paged, 25 per page |
| Users | fetched every user | paged, 25 per page |
| Dashboard counts | fetched every row and measured the array | counted in the database |

The cap was the worse of the two: an unbounded query gets slow, but a silent cap
means a busy site's older enquiries simply are not there, with nothing on the
screen to say so.

`Paginator@core` does the arithmetic once, and `/core/views/_pagination.cfm`
renders the pager. Filters survive paging — the enquiries pager keeps
`?status=new` — because a pager that drops the filter sends you somewhere you
did not ask to go.

## 9. What is implemented

- `AuthenticationService`, `CsrfService`, `AdminNavigationRegistry`,
  `SecuredHandler` and the `core:Security` diversion screens, all in Core.
- The admin module: sign-in, dashboard, users, roles, settings, and the shared
  chrome.
- The Pages module's own admin screens, contributed through the registry.
- 40 passing specs for this group; 493 across Groups 1-8.

## 10. What is intentionally postponed

| Area | Why it waits |
| --- | --- |
| Password reset and invitations | Needs a mail layer, which does not exist. An admin sets passwords directly for now. |
| Rate limiting and lockout on failed sign-ins | Belongs with a store that survives a restart; the sign-in path logs failures in the meantime. |
| Two-factor authentication | Follows the reset flow. |
| A rich text editor | **Delivered in Group 7** — CKEditor 5, self-hosted. See [contact-and-editing.md](contact-and-editing.md). |
| HTML sanitisation of page content | **Closed in Group 6** — content is sanitised unless the author holds `content.unfiltered`. See [blog.md](blog.md). |
| Audit log | Who changed what, and when. Needs its own table and a retention decision. |
| Search and filtering on the lists | The lists are paged now, but finding one enquiry among a thousand still means walking the pages. |
| Pagination on the pages tree | A tree is shown whole so the hierarchy reads correctly; a site with thousands of pages would need a different screen, not a pager. |
| Drag-and-drop reordering | `sort_order` is editable as a number; `PageService.reorderPages()` already exists for a UI to call. |
| Super admin cross-site switcher | A super admin administers whichever site's domain they signed in at. |
