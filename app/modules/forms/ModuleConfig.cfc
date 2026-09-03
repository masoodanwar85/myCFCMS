/**
 * Forms — author-defined forms with their own fields.
 *
 * The other half of the split that shrank Contact back to one enquiry form.
 * Contact owns a site's way of being contacted; this owns forms whose *fields*
 * an author defines — a registration, a booking request, a survey.
 *
 * It hangs off the same seams every other feature module uses, and Core did not
 * change to accommodate it:
 *
 *   - embedding in content -> ShortcodeRegistry        (Group 9)
 *   - receiving a POST     -> ContentResolverRegistry  (Group 4)
 *   - admin screens        -> its own entry point + SecuredHandler (Group 5)
 *   - admin navigation     -> AdminNavigationRegistry  (Group 5)
 *   - permissions          -> its own migration into Core's catalogue (Group 2)
 *
 * No public URLs of its own. A form appears where an author puts it, which is
 * the whole point of building it as a shortcode rather than as a set of routes.
 */
component {

	this.title       = "Forms";
	this.author      = "myCFCMS";
	this.description = "Author-defined forms, their fields and the responses sent through them.";
	this.version     = "1.0.0";

	this.cfmapping      = "forms";
	this.modelNamespace = "forms";
	this.autoMapModels  = true;

	this.entryPoint        = "admin/forms";
	this.inheritEntryPoint = false;

	this.dependencies = [ "core" ];

	function configure(){
		settings = {
			// Off by default, like Contact's. A CMS that starts emailing the
			// moment it is installed is a CMS that emails the wrong people.
			"sendNotifications"    : false,
			// Responses per hour from one address. 0 switches it off.
			"maxPerHourPerAddress" : 20,
			// A field a person never sees and never fills in.
			"honeypotField"        : "website"
		};

		routes = [ { pattern : "/:action?/:id?", handler : "Admin" } ];
	}

	function onLoad(){
		// Behind Pages and Contact: this resolver claims no URLs of its own and
		// only ever answers a POST that names one of its forms.
		wirebox
			.getInstance( "ContentResolverRegistry@core" )
			.register( "FormContentResolver@forms", 70 );

		wirebox
			.getInstance( "ShortcodeRegistry@core" )
			.register(
				tag         = "form",
				id          = "FormShortcode@forms",
				description = 'Embeds one of this site''s forms: [form slug="registration"]'
			);

		wirebox
			.getInstance( "AdminNavigationRegistry@core" )
			.register(
				label      = "Forms",
				href       = "/admin/forms",
				permission = "forms.view",
				order      = 44,
				group      = "Modules"
			);
	}

	function onUnload(){
		wirebox.getInstance( "ContentResolverRegistry@core" ).unregister( "FormContentResolver@forms" );
		wirebox.getInstance( "ShortcodeRegistry@core" ).unregister( "form" );
		wirebox.getInstance( "AdminNavigationRegistry@core" ).unregister( "/admin/forms" );
	}

}
