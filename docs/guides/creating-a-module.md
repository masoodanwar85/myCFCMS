# Creating a module, step by step

This is a recipe. Each step is a folder, a file, or a command you create.

**Contact is the example.** Every path below is a real file in this repo. To
build a *new* module, do the same steps and rename `contact` to your module
name (`faq`, `news`, `events`, …).

You do **not** edit Core, the admin module, or `config/Router.cfc`. Dropping a
folder under `app/modules/` with a `ModuleConfig.cfc` is enough for ColdBox to
load it.

Once the files exist, [module-request-flow.md](module-request-flow.md) traces
one admin request and one frontend request through Contact, step by step.

---

## Before you start

Write down four names. For Contact they were:

| What | Contact's answer | Yours |
| --- | --- | --- |
| Folder / WireBox namespace | `contact` | |
| Admin URL | `/admin/contact` | `/admin/…` |
| Public URL, if any | `/contact` | `/…` or none |
| Permission prefix | `contact.view`, `contact.manage` | `{name}.view`, … |

Also decide which of these you need. Skip the steps marked optional if not.

| Need | Contact | Steps |
| --- | --- | --- |
| Database tables | yes | 3 |
| Permissions + admin screens | yes | 4, 11, 12 |
| A public page | yes (`/contact`) | 8, 13 |
| A public form that saves data | yes | 8b |
| A link in the site menu | yes | 9 |

---

## Step 1. Create the folder

```
app/modules/contact/
```

For a new module: `app/modules/{name}/`.

Create the subfolders you will fill in later:

```
app/modules/contact/
    handlers/
    models/
    views/admin/
```

ColdBox will not load this yet. It looks for `ModuleConfig.cfc` next.

---

## Step 2. Create `ModuleConfig.cfc`

Create:

```
app/modules/contact/ModuleConfig.cfc
```

Put this in it (this *is* Contact's file, with the registry calls left for
step 10):

```cfc
component {

    this.title       = "Contact";
    this.author      = "myCFCMS";
    this.description = "Per-site contact forms and the enquiries sent through them.";
    this.version     = "1.0.0";

    this.cfmapping      = "contact";
    this.modelNamespace = "contact";
    this.autoMapModels  = true;

    this.entryPoint        = "admin/contact";
    this.inheritEntryPoint = false;

    this.dependencies = [ "core" ];

    function configure(){
        settings = {
            "basePath" : "contact"
        };

        routes = [ { pattern : "/:action?/:id?", handler : "Admin" } ];
    }

    function onLoad(){
    }

    function onUnload(){
    }

}
```

For a new module, change every `contact` / `Contact` in that file.

What those properties mean, in the order you will hit them:

- `cfmapping` + `modelNamespace` — your CFCs are injected as
  `ContactService@contact`.
- `autoMapModels` — every CFC under `models/` is wired automatically. Do not
  also map them by hand.
- `entryPoint = "admin/contact"` — admin URLs start here.
  `/admin/contact` → `Admin.index`, `/admin/contact/view/12` → `Admin.view`.
- `inheritEntryPoint = false` — leave it false.
- `dependencies = [ "core" ]` — Core loads first, because step 10 talks to it.
- `settings` — defaults. Inject later with `coldbox:moduleSettings:contact`.
- `routes` — only the **admin** routes. Public URLs are *not* declared here.

Reinit the app (`?fwreinit=1`). The module now loads. It does nothing yet.

---

## Step 3. Create the tables

Create a migration:

```
resources/database/migrations/YYYY_MM_DD_HHMMSS_create_contact_tables.cfc
```

Contact's is `2026_08_24_170000_create_contact_tables.cfc`. The timestamp is
the run order — later than Core's `sites` and `permissions` tables, because
you will foreign-key onto them.

Minimum shape every module table follows:

- `id` bigint unsigned, PK
- `site_id` bigint unsigned, `FK → sites.id` `ON DELETE CASCADE`
- unique `(site_id, slug)` if the row is looked up by slug
- unique `(id, site_id)` if another table will point at this one
- InnoDB, `utf8mb4`, `utf8mb4_unicode_ci`

Contact created two tables. The child references the parent with a
**composite** key, so a submission cannot attach to another site's form:

```sql
CONSTRAINT `fk_contact_submissions_form`
    FOREIGN KEY (`form_id`, `site_id`)
    REFERENCES `contact_forms` (`id`, `site_id`)
    ON DELETE CASCADE
```

Copy Contact's migration and rename the tables. `down()` drops children first.

Then run:

```
box migrate up
```

---

## Step 4. Create the permissions

Create a second migration, timestamped one second later:

```
resources/database/migrations/YYYY_MM_DD_HHMMSS_seed_contact_permissions.cfc
```

Contact's is `2026_08_24_170100_seed_contact_permissions.cfc`. Copy it. Change
the array:

```cfc
variables.PERMISSIONS = [
    { slug : "contact.view",               name : "View enquiries",   description : "…" },
    { slug : "contact.manage",             name : "Manage forms",     description : "…" },
    { slug : "contact.submissions.delete", name : "Delete enquiries", description : "…" }
];
```

For a new module: `{name}.view`, `{name}.create`, `{name}.update`,
`{name}.delete` — whatever the admin screens will actually check. This
migration **inserts slugs only**. It does not grant them to any role.

Run:

```
box migrate up
```

Existing sites' `owner` role will not see the new slugs until you re-seed
(step 16). New sites get them automatically.

---

## Step 5. Create the entity

Create one CFC per table, under `models/`. Contact's form:

```
app/modules/contact/models/ContactForm.cfc
```

```cfc
component accessors="true" {

    property name="id"     type="numeric";
    property name="siteId" type="numeric";
    property name="name"   type="string";
    property name="slug"   type="string";
    // …one property per column, camelCase

    function init(){
        variables.isActive = true;
        return this;
    }

    struct function getMemento(){
        return {
            "id"     : variables.id,
            "siteId" : variables.siteId,
            "name"   : variables.name,
            "slug"   : variables.slug
        };
    }

}
```

No injected services. No SQL. Defaults in `init()`. Contact also has
`Submission.cfc` for the second table.

---

## Step 6. Create the repository

```
app/modules/contact/models/ContactRepository.cfc
```

```cfc
component singleton extends="core.models.persistence.BaseRepository" {

    variables.FORM_TABLE = "contact_forms";
    variables.FORM_COLS  = [
        "id", "site_id", "name", "slug", /* … */
        "created_at", "updated_at"
    ];

    contact.models.ContactForm function createForm( required contact.models.ContactForm form ){
        var stamp  = now();
        var result = variables.query
            .from( variables.FORM_TABLE )
            .insert( {
                "site_id"    : arguments.form.getSiteId(),
                "name"       : arguments.form.getName(),
                "slug"       : arguments.form.getSlug(),
                "created_at" : { value : stamp, cfsqltype : "cf_sql_timestamp" },
                "updated_at" : { value : stamp, cfsqltype : "cf_sql_timestamp" }
            } );

        arguments.form.setId( generatedKey( result, variables.FORM_TABLE ) );
        return arguments.form;
    }

    function findFormById( required numeric id ){
        var row = formQuery().where( "id", arguments.id ).first();
        if ( row.isEmpty() ) {
            return;
        }
        return toForm( row );
    }

    array function findFormsForSite( required numeric siteId ){
        return formQuery()
            .where( "site_id", arguments.siteId )
            .get()
            .map( ( row ) => toForm( row ) );
    }

    private function formQuery(){
        return variables.query.from( variables.FORM_TABLE ).select( variables.FORM_COLS );
    }

    contact.models.ContactForm function toForm( required struct row ){
        return wirebox
            .getInstance( "ContactForm@contact" )
            .setId( arguments.row.id )
            .setSiteId( arguments.row.site_id )
            .setName( arguments.row.name )
            .setSlug( arguments.row.slug );
    }

}
```

Rules for this file:

- Extend `BaseRepository`. That gives you `generatedKey()`,
  `isUniqueViolation()` and `isForeignKeyViolation()`.
- Every list/find that returns tenant data filters on `site_id`.
- Catch a unique violation and throw a typed error (`Contact.FormSlugExists`).
- Map `site_id` → `setSiteId()`, never expose query rows to handlers.

Copy the rest from Contact's repository (update, delete, submissions, paging).

---

## Step 7. Create the service

```
app/modules/contact/models/ContactService.cfc
```

```cfc
component singleton accessors="true" {

    property name="contactRepository" inject="ContactRepository@contact";
    property name="siteRepository"    inject="SiteRepository@core";
    property name="slugifier"         inject="Slugifier@core";
    property name="settings"          inject="coldbox:moduleSettings:contact";
    property name="wirebox"           inject="wirebox";

    contact.models.ContactForm function createForm(
        required numeric siteId,
        required string name
    ){
        if ( isNull( siteRepository.findById( arguments.siteId ) ) ) {
            throw( type = "Contact.SiteNotFound", message = "No site with id [#arguments.siteId#]." );
        }

        var formName = trim( arguments.name );
        if ( !len( formName ) ) {
            throw( type = "Contact.InvalidForm", message = "A form requires a name." );
        }

        var formSlug = slugifier.slugify( formName );

        var contactForm = wirebox
            .getInstance( "ContactForm@contact" )
            .setSiteId( arguments.siteId )
            .setName( formName )
            .setSlug( formSlug );

        return contactRepository.createForm( contactForm );
    }

}
```

Rules for this file:

- Take `siteId` as an argument. Do not read `TenantContext`.
- Throw typed errors (`Contact.InvalidForm`). Do not return `false`.
- Do **not** check permissions. The admin handler does that.
- Use `Slugifier@core` for slugs. Do not copy a `slugify()` function.
- Handlers and resolvers call the service, never the repository.

Copy Contact's `updateForm`, `deleteForm`, `getFormsForSite`, `submit`, etc.
as you need them.

At this point the module has data and no screens. You can already call
`getInstance( "ContactService@contact" )` from a spec.

---

## Step 8. Serve a public URL *(skip if admin-only)*

Create:

```
app/modules/contact/models/ContactContentResolver.cfc
```

```cfc
component singleton accessors="true" {

    property name="contactService" inject="ContactService@contact";
    property name="settings"       inject="coldbox:moduleSettings:contact";

    function resolveContent( required numeric siteId, required string path ){
        var base = lCase( trim( settings.basePath ?: "contact" ) );

        if ( arguments.path != base ) {
            return;   // not ours — Pages will get a turn
        }

        var contactForm = contactService.getDefaultForm( arguments.siteId );
        if ( isNull( contactForm ) ) {
            return;   // nothing to show — an ordinary /contact page still works
        }

        return {
            "view"            : "contact-form",
            "args"            : { "form" : contactForm },
            "title"           : contactForm.getName(),
            "metaDescription" : "",
            "statusCode"      : 200
        };
    }

}
```

The `view` name (`contact-form`) is a file you will create in the theme in
step 13. The path is **without** leading slashes (`contact`, not `/contact`).

If the path is not yours, `return;` with no value. Do not throw. Do not return
an empty struct.

You will register this CFC in step 10. Until then it does nothing.

### Step 8b. Accept a public POST *(skip unless visitors submit data)*

Add this method to the same resolver. Contact is the only module that has it.

```cfc
function handleSubmission(
    required numeric siteId,
    required string path,
    required struct formData
){
    if ( arguments.path != "contact" ) {
        return;
    }

    // 1. CSRF — refuse, redisplay, store nothing
    // 2. honeypot — pretend success, store nothing
    // 3. validate — redisplay with errors
    // 4. contactService.submit(...)
    // 5. return { "redirectTo" : "/contact/thank-you" }
}
```

The real method is in `ContactContentResolver.cfc`. Copy it if your module
takes input from people who are not signed in. Do not invent a public route
in `config/Router.cfc` — Core already POSTs to the catch-all and asks every
resolver for `handleSubmission`.

---

## Step 9. Add a public menu link *(skip if no public URL)*

Create:

```
app/modules/contact/models/ContactNavigationProvider.cfc
```

```cfc
component singleton accessors="true" {

    property name="contactService" inject="ContactService@contact";
    property name="settings"       inject="coldbox:moduleSettings:contact";

    array function getNavigationItems( required numeric siteId ){
        var contactForm = contactService.getDefaultForm( arguments.siteId );
        if ( isNull( contactForm ) ) {
            return [];
        }

        return [
            {
                "label" : contactForm.getName(),
                "href"  : "/contact",
                "order" : 900
            }
        ];
    }

}
```

Return structs, not entities. Return `[]` when there is nothing to link to.
You will register this in step 10.

---

## Step 10. Register with Core

Go back to `ModuleConfig.cfc` and fill in `onLoad` / `onUnload`. Contact's:

```cfc
function onLoad(){
    wirebox
        .getInstance( "ContentResolverRegistry@core" )
        .register( "ContactContentResolver@contact", 60 );

    wirebox
        .getInstance( "SiteNavigationRegistry@core" )
        .register( "ContactNavigationProvider@contact", 60 );

    wirebox
        .getInstance( "AdminNavigationRegistry@core" )
        .register(
            label      = "Enquiries",
            href       = "/admin/contact",
            permission = "contact.view",
            order      = 42,
            group      = "Modules"
        );
}

function onUnload(){
    wirebox.getInstance( "ContentResolverRegistry@core" )
        .unregister( "ContactContentResolver@contact" );
    wirebox.getInstance( "SiteNavigationRegistry@core" )
        .unregister( "ContactNavigationProvider@contact" );
    wirebox.getInstance( "AdminNavigationRegistry@core" )
        .unregister( "/admin/contact" );
}
```

Change the WireBox ids, href, label, permission, and order.

Priority for the content resolver: **lower runs first**. Pages is `100` (the
catch-all). Blog is `50`. Contact is `60`. Pick a number below `100` so your
prefix is not swallowed by a page with the same slug.

Admin nav:

- `group = "Modules"` for an installed feature, `"CMS"` for site-building
  (Pages, Media).
- `order` — lower sorts first. Contact uses `42` (just after Blog's `40`).
- `permission` — anyone who cannot pass this check will not see the link.

If you skipped step 8, omit the content-resolver lines. If you skipped step 9,
omit the site-nav lines. If you have no admin, omit the admin-nav lines.

Reinit. `/admin/contact` now appears in the admin bar for anyone with
`contact.view` (owner, after step 16). Clicking it 404s until step 11.

---

## Step 11. Create the admin handler

Create:

```
app/modules/contact/handlers/Admin.cfc
```

```cfc
component extends="core.models.security.SecuredHandler" {

    property name="contactService" inject="ContactService@contact";

    variables.permissions = {
        "index"  : "contact.view",
        "view"   : "contact.view",
        "forms"  : "contact.manage",
        "$every" : "contact.view"
    };

    function index( event, rc, prc ){
        prc.pageTitle   = "Enquiries";
        prc.submissions = contactService.getSubmissions( prc.currentSite.getId() );
        event.setView( view = "admin/index", module = "contact" );
    }

    function view( event, rc, prc ){
        prc.submission = requireSiteSubmission( rc.id ?: 0, prc );
        prc.pageTitle  = "Enquiry";
        event.setView( view = "admin/view", module = "contact" );
    }

    private function requireSiteSubmission( required numeric id, required struct prc ){
        var submission = contactService.getSubmissionById( arguments.id );

        if ( isNull( submission ) || submission.getSiteId() != arguments.prc.currentSite.getId() ) {
            throw( type = "Admin.NotFoundHere", message = "No enquiry [#arguments.id#] on this site." );
        }

        return submission;
    }

}
```

Do these four things in every admin handler:

1. `extends="core.models.security.SecuredHandler"` — not the admin module.
2. List **every** action in `variables.permissions`. An action you forget is
   refused, not allowed. `$every` is the fallback.
3. Check every URL id against `prc.currentSite.getId()`. Throw
   `Admin.NotFoundHere` if it is missing or belongs to another site.
4. `event.setView( view = "admin/…", module = "contact" )` so ColdBox looks in
   *this* module's `views/` folder.

Mutating actions (`remove`, `createForm`, …) `return done( "/admin/contact", "Saved." );`
which flashes a message and redirects. Pass `"error"` as the third argument
when the service threw.

Copy Contact's remaining actions (`status`, `remove`, `forms`, `createForm`,
`updateForm`, `deleteForm`) from
`app/modules/contact/handlers/Admin.cfc`.

---

## Step 12. Create the admin views

Create one `.cfm` per `setView` you called.

```
app/modules/contact/views/admin/index.cfm
app/modules/contact/views/admin/view.cfm
app/modules/contact/views/admin/forms.cfm
```

A list view starts like this:

```cfm
<cfoutput>
<h1>Enquiries</h1>

<table>
    <thead><tr><th>From</th><th>Subject</th><th></th></tr></thead>
    <tbody>
        <cfloop array="#prc.submissions#" index="s">
            <tr>
                <td>#encodeForHTML( s.getName() )#</td>
                <td>#encodeForHTML( s.getSubject() )#</td>
                <td>
                    <a class="ico" href="/admin/contact/view/#s.getId()#">Read</a>
                </td>
            </tr>
        </cfloop>
    </tbody>
</table>
</cfoutput>
```

Rules for every admin view:

- Escape with `encodeForHTML` / `encodeForHTMLAttribute`. Use `xmlFormat()`
  for a URL in an attribute.
- Every action that *changes* data is a `<form method="post">` with
  `<input type="hidden" name="csrfToken" value="#encodeForHTMLAttribute( prc.csrfToken )#">`.
  Never a link.
- Reuse the classes in Core's admin CSS: `.adm-toolbar`, `.btn`, `.ico`,
  `.ico.danger`, `.pill.on`, `.pill.off`.
- Long lists: `Paginator@core` in the handler, then
  `<cfinclude template="/core/views/_pagination.cfm">`.

Copy Contact's three views rather than restyling from scratch.

---

## Step 13. Create the theme views *(skip if no public URL)*

The resolver in step 8 returned `"view" : "contact-form"`. That file has to
exist in **each** theme:

```
themes/default/views/contact-form.cfm
themes/starter/views/contact-form.cfm
themes/willcreator/views/contact-form.cfm
```

Create it in `default` first:

```cfm
<cfoutput>
<article>
    <h1>#encodeForHTML( args.form.getName() )#</h1>
    <!--- body of the page --->
</article>
</cfoutput>
```

`args` is whatever you put in the resolver's `args` struct, plus `args.site`.
This is a fragment — the theme layout wraps it.

If you have a thank-you page, add `contact-sent.cfm` the same way. Contact's
form view also has the CSRF field, honeypot, and error list; copy those if
you built step 8b.

Then copy the file into every other shipped theme. A site whose theme is
missing the view will error when someone hits the URL.

---

## Step 14. Write a spec

Create:

```
tests/specs/integration/contact/ContactSpec.cfc
```

Minimum it should prove:

```cfc
component extends="coldbox.system.testing.BaseTestCase" appMapping="/app" {

    function run(){
        describe( "Contact", function(){

            it( "creates a form scoped to its site", function(){
                // contact.createForm(...) → siteId matches
            } );

            it( "allows the same slug on another site", function(){
                // same name on site two does not throw
            } );

            it( "registers a resolver ahead of Pages", function(){
                var registered = getInstance( "ContentResolverRegistry@core" ).getRegistered();
                expect( registered ).toInclude( "ContactContentResolver@contact" );
            } );

            it( "registers its admin navigation", function(){
                expect(
                    getInstance( "AdminNavigationRegistry@core" )
                        .getSections().map( ( s ) => s.href )
                ).toInclude( "/admin/contact" );
            } );

            it( "registers its permissions into Core's catalogue", function(){
                var slugs = getInstance( "RoleService@core" )
                    .getAllPermissions().map( ( p ) => p.getSlug() );
                expect( slugs ).toInclude( "contact.view" );
            } );

        } );
    }

}
```

Use a unique site-slug prefix (`zzt-ct-` in Contact) and delete those sites in
`afterAll`, or the next run will collide.

```
box testbox run bundles=tests.specs.integration.contact.ContactSpec
```

Copy the rest of Contact's spec for public GET/POST, validation, and
throttling if you built those.

---

## Step 15. Apply it

```
box migrate up
```

Reinit the framework (`?fwreinit=1`).

Give existing sites the new permissions on `owner`:

```cfc
getInstance( "RoleService@core" ).seedDefaultRolesForSite( siteId );
```

That call is idempotent. New sites get owner grants when they are provisioned.

Then, in the browser, on a tenant domain:

1. Sign in. The admin bar shows **Enquiries** (or your label).
2. Open it. The list view from step 12 renders.
3. If you have a public URL: create whatever content the resolver needs (for
   Contact, a form under **Forms**), then open `/contact`.
4. On **Roles**, grant `{name}.view` to any non-owner role that should see the
   section. Until you do, only owner sees it.

---

## Done. Files you created

For Contact, the full set is:

```
app/modules/contact/ModuleConfig.cfc                          steps 2, 10
app/modules/contact/models/ContactForm.cfc                    step 5
app/modules/contact/models/Submission.cfc                     step 5
app/modules/contact/models/ContactRepository.cfc              step 6
app/modules/contact/models/ContactService.cfc                 step 7
app/modules/contact/models/ContactContentResolver.cfc         step 8
app/modules/contact/models/ContactNavigationProvider.cfc      step 9
app/modules/contact/handlers/Admin.cfc                        step 11
app/modules/contact/views/admin/index.cfm                     step 12
app/modules/contact/views/admin/view.cfm                      step 12
app/modules/contact/views/admin/forms.cfm                     step 12
resources/database/migrations/…_create_contact_tables.cfc     step 3
resources/database/migrations/…_seed_contact_permissions.cfc  step 4
themes/default/views/contact-form.cfm                         step 13
themes/default/views/contact-sent.cfm                         step 13
tests/specs/integration/contact/ContactSpec.cfc               step 14
```

Nothing in `app/modules/core/`, `app/modules/admin/`, or `app/config/Router.cfc`
was edited.

---

## If your module is smaller than Contact

| You are building | Do steps | Stop after |
| --- | --- | --- |
| Admin-only (like Media) | 1–7, 10 (admin-nav only), 11, 12, 14, 15 | no resolver, no theme views |
| Public pages, no form (like Blog) | 1–13, skip 8b | no `handleSubmission` |
| Public form (like Contact) | all of them | — |

Do not add a sitemap, shortcode, or REST resource unless you need them. Those
are extra `onLoad` registrations; Pages and Blog show the pattern, Contact
does not use them.
