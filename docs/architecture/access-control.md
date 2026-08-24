# Users, Roles and Permissions (Group 2)

How myCFCMS decides who someone is, which tenant they belong to, and what they
are allowed to do there.

Read [multi-tenancy.md](multi-tenancy.md) first — everything here hangs off the
`sites` table and the request's `TenantContext`.

---

## 1. The three decisions this group is built on

**A user belongs to exactly one site.** Not a membership list, not a join table:
one `site_id` on the user row. Each client's staff exist only inside that
client's site.

**Except the platform super admin**, who belongs to no site and reaches all of
them. There is exactly one way to be a super admin — see below.

**Roles are defined per site; permissions are global.** Each client shapes its
own roles out of a shared catalogue of capabilities. That split follows from who
owns what: a permission such as `pages.publish` is defined by the *code* that
implements publishing, while "who counts as an Editor here" is the client's
business.

---

## 2. Database strategy

Five tables, all InnoDB / `utf8mb4` / `utf8mb4_unicode_ci`.

```
                  sites  (Group 1)
                    |
        +-----------+-----------+
        |                       |
      users                   roles
        |                       |
        +-------- user_roles ---+
                                |
                        role_permissions
                                |
                          permissions   (global catalogue)
```

### `users`

| Column | Type | Notes |
| --- | --- | --- |
| `id` | `BIGINT UNSIGNED` | PK |
| `site_id` | `BIGINT UNSIGNED` **NULL** | FK → `sites.id`, cascade. **NULL means platform super admin.** |
| `name` | `VARCHAR(150)` | Display name |
| `email` | `VARCHAR(191)` | Login identifier |
| `password_hash` | `VARCHAR(255)` | BCrypt |
| `status` | `VARCHAR(20)` | `active` / `inactive`, `CHECK`-constrained |
| `created_at` / `updated_at` | `DATETIME` | |

**There is no `is_super_admin` column, deliberately.** A flag plus a `site_id`
can contradict each other, and the contradictory row — a user marked as an
ordinary user but belonging to no site — is exactly the one that slips past
every site-scoped check. With the fact carried by one column, that state cannot
be written at all.

The original design *did* have the flag, reconciled by a `CHECK` constraint.
MySQL rejects it: a column carrying a foreign key referential action cannot also
appear in a `CHECK`. Keeping `ON DELETE CASCADE` consistent with Group 1 was
worth more than the flag.

**`uq_users_scope_email` — `( (COALESCE(site_id, 0)), email )`.** Email is unique
*within a tenant*, because two unrelated clients may each legitimately have a
user at `info@`. `COALESCE(site_id, 0)` is a functional key part so super admins
— whose `site_id` is `NULL` — still collide with each other; a plain
`(site_id, email)` index would not, since MySQL never treats two `NULL`s as
equal. That subtlety is the difference between "two super admins cannot share an
address" and silently allowing duplicates.

### `roles`

Per site: `uq_roles_site_slug (site_id, slug)`. Two clients can both have a
`reviewer`; neither can have two.

### `permissions`

Global catalogue, unique on `slug`. Rows arrive through **migrations** — Core's
twelve in Group 2, and each feature module's alongside its own tables. There is
deliberately no runtime create/update API: a permission that no code checks is
decoration, and one invented at runtime cannot be checked by code that shipped
earlier.

### `role_permissions`

`PRIMARY KEY (role_id, permission_id)` — so granting is idempotent by
construction rather than by a service remembering to check first.

### `user_roles` — the important one

| Column | Type |
| --- | --- |
| `user_id` | `BIGINT UNSIGNED` |
| `role_id` | `BIGINT UNSIGNED` |
| `site_id` | `BIGINT UNSIGNED` |
| `created_at` | `DATETIME` |

```sql
CONSTRAINT fk_user_roles_user FOREIGN KEY (user_id, site_id) REFERENCES users (id, site_id)
CONSTRAINT fk_user_roles_role FOREIGN KEY (role_id, site_id) REFERENCES roles (id, site_id)
```

`site_id` is denormalised here on purpose, so that both foreign keys can be
**composite**. The row asserts "this user, this role, both on this site", and
MySQL checks both halves. Assigning site A's role to site B's user is therefore
not merely rejected by a service method — it cannot be stored.

In a shared-database tenancy model, cross-tenant privilege assignment is the
worst bug available: it is silent, it grants real access, and it is invisible in
any single-tenant test. One denormalised column to make it unrepresentable is a
good trade. `users` and `roles` each carry a `UNIQUE (id, site_id)` purely to be
the target of these keys.

The integration specs prove it both ways: through the service, and by going
straight at the repository with each site id in turn.

---

## 3. Authorisation

`AuthorizationService` is the only place that answers *"may this user do this?"*,
and every check is **two** questions in order:

1. **Tenancy** — does the user belong to the site this action targets?
2. **Permission** — do their roles on that site grant it?

The first is the one that is easy to forget. A user holding `users.delete` on
their own site must not be able to delete users on another; checking the
permission alone would let them. So the site is always part of the question.

```cfc
property name="auth" inject="AuthorizationService@core";

// Explicit site
auth.can( user, "users.create", siteId )

// Site defaults to the tenant this request resolved to
auth.can( user, "users.create" )

// Enforce — throws Auth.NotAuthorized
auth.assertCan( user, "users.create" )
```

| Method | Behaviour |
| --- | --- |
| `can` / `cannot` | Return a boolean. Never throw — branch on them freely. |
| `assertCan` | Throws `Auth.NotAuthorized`. Named to stay clear of engine built-ins. |
| `canAll` / `canAny` | Every / at least one. |
| `hasRole` | Role membership, not permission. |
| `getPermissionsFor` | Every slug the user holds. |

**Where the site comes from.** An explicit `siteId` wins; otherwise
`TenantContext.getCurrentTenantId()`. If neither is available and the user is
not a super admin, the answer is **deny** — an unresolved tenant is not a reason
to guess.

**Super admins** short-circuit before any query: they are not *granted*
permissions, they *bypass* the check. `getPermissionsFor()` therefore returns an
empty array for them, which is why authorisation decisions must go through
`can()` and never through that list.

**Inactive users are denied everything**, super admins included. Deactivating an
account is the fastest lever an operator has, so it is checked first.

---

## 4. Passwords

`PasswordService` wraps the Ortus BCrypt module. It exists so nothing else
touches a hashing library directly: the work factor is set in one place, and a
future algorithm change is one file.

- BCrypt, work factor **12** (`core` module setting `passwordWorkFactor`).
- Minimum length **12 characters**, and no composition rules — length is what
  resists guessing, while character-class rules mostly produce predictable
  substitutions.
- `verify()` returns `false` for a wrong password, an empty password or a
  malformed hash. It never throws, because a wrong password is an expected
  outcome, and an exception a caller mishandles could read as success.
- `User.getMemento()` never includes the hash.

**`UserService.verifyPassword()` is the only authentication in this group, and
it stops there.** It confirms a password against a hash and returns a boolean —
an inactive user always fails, whatever they type. No session, no cookie, no
token, no "remember me". Establishing identity and carrying it across requests
belongs with routing and the API layer, and building it now would mean deciding
session and token policy before the layer that consumes them exists.

---

## 5. Code layout

```
app/modules/core/models/
    auth/
        User.cfc                  Entities: state only.
        Role.cfc
        Permission.cfc
        UserRepository.cfc        All SQL, scoped by site.
        RoleRepository.cfc        Roles + both join tables.
        PermissionRepository.cfc  Read-mostly catalogue.
        PasswordService.cfc       BCrypt seam.
        UserService.cfc           User use cases.
        RoleService.cfc           Role and permission use cases.
        AuthorizationService.cfc  The only "may they?" answer.
    persistence/
        BaseRepository.cfc        Now also tells unique from FK violations.
    tenancy/                      Group 1
```

`RoleRepository` owns `role_permissions` and `user_roles` rather than giving each
a repository of its own: neither has an identity or a lifecycle beyond the role
it hangs off, so splitting them would buy indirection and nothing else.

### Core permission catalogue

| Slug | |
| --- | --- |
| `site.view` `site.update` | The tenant's own record |
| `site.domains.manage` `site.settings.manage` | Group 1 surfaces |
| `users.view` `users.create` `users.update` `users.delete` | People |
| `roles.view` `roles.create` `roles.update` `roles.delete` | Access control |

### Default roles

`RoleService.seedDefaultRolesForSite( siteId )` gives a site two roles:

- **Owner** — every permission in the catalogue, resolved at seed time rather
  than from a fixed list. "Full control" has to keep meaning that as modules
  register new capabilities; when the Pages module landed, a hard-coded list
  would have quietly stopped being complete. Re-running the seeder on an
  existing site is how it picks up a newly installed module's permissions.
- **Editor** — `site.view`, `users.view`, `roles.view`. A non-privileged role to
  hand out, widened with content permissions by later groups.

Two, not five. Anything more would be guessing at each client's org chart.

### Provisioning a site

```cfc
var site = siteService.createSite( name = "Client One" );
siteService.addDomain( site.getId(), "client.com" );
roleService.seedDefaultRolesForSite( site.getId() );

var owner = userService.createUser( site.getId(), "Ada", "ada@client.com", "..." );
userService.assignRole( owner.getId(), roleService.getRoleBySlugForSite( "owner", site.getId() ).getId() );
```

Seeding is a **separate, explicit call**, not a hook inside `SiteService`.
Tenancy has no business knowing that authorisation exists: the dependency runs
one way, from access control towards tenancy, and not back. It is idempotent, so
re-running it on an existing site is safe.

---

## 6. Errors

All typed, so callers can branch instead of matching on message text.

| Type | Raised when |
| --- | --- |
| `Auth.SiteNotFound` | The target site does not exist |
| `Auth.UserNotFound` / `Auth.RoleNotFound` | Unknown id |
| `Auth.InvalidUser` / `Auth.InvalidRole` | Failed validation |
| `Auth.EmailAlreadyTaken` | Address in use *in that scope* |
| `Auth.RoleSlugAlreadyTaken` | Slug in use on that site |
| `Auth.WeakPassword` | Below the minimum length |
| `Auth.PermissionNotFound` | Slug is not in the catalogue |
| `Auth.CrossTenantRoleAssignment` | User and role are not on the same site |
| `Auth.SuperAdminRolesUnsupported` | Tried to give a super admin a site role |
| `Auth.NotAuthorized` | `assertCan` denied |

---

## 7. What is implemented

- `users`, `roles`, `permissions`, `role_permissions`, `user_roles` — migration,
  indexes, composite foreign keys, `CHECK` constraint, cascade deletes.
- The twelve Core permissions, seeded by migration.
- Entities, repositories and services for all five tables.
- BCrypt password hashing and verification.
- `AuthorizationService`, integrated with `TenantContext`.
- Default per-site roles, seeded idempotently.
- 188 passing specs for Groups 1 and 2; 346 across Groups 1-5.

## 8. What is intentionally postponed

| Area | Why it waits |
| --- | --- |
| Login and sessions | **Delivered in Group 5** — see [admin.md](admin.md). JWT still waits for the API layer. |
| Password reset / email verification | Requires a mail layer, which does not exist. |
| Rate limiting and lockout on failed attempts | Belongs with the login flow, not the data model. |
| Audit log of permission changes | Real requirement eventually; needs its own table and a decision on retention. |
| Per-user permission overrides | Roles only, for now. Overrides make "why can this person do that?" much harder to answer, and no requirement calls for them yet. |
| Role hierarchies / inheritance | Flat roles are enough for the current permission set. |
| Two-factor authentication | Follows the login flow. |
| Admin UI for users and roles | No handlers or views in this group — services only. |
| Automatic `site_id` scoping in the query builder | Still deliberate. Repositories scope explicitly; revisit as a query-builder concern once content modules multiply the number of tenant-owned tables. |

---

## 9. Running it

```bash
box migrate up            # applies Groups 1 and 2 in order
box migrate down          # rolls back one migration
```

Tests: start the server and open `/tests/runner.cfm`. Integration specs need
migrations to have run; rows they create are prefixed `zzt-` and cleaned up.
