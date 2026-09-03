/**
 * Contact — the third feature module, and the first to accept input from
 * people who are not signed in.
 *
 * Every other write path in the CMS sits behind authentication and a
 * permission. This one is open to the internet, which is a different problem:
 * the module has to assume the caller is hostile, and Core had to grow a way to
 * route a public POST to a module — see ContentResolverRegistry.resolveSubmission.
 *
 * Like Pages and Blog, it depends on Core alone.
 */
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
			// Public URL the form is served at and posts back to.
			"basePath"        : "contact",
			// Where a successful send lands, so a refresh cannot resend.
			"thankYouSegment" : "thank-you",
			// Name of the hidden field a bot will fill in and a person will not.
			"honeypotField"   : "website",
			// Messages accepted from one address per hour. Zero disables it.
			"maxPerHourPerAddress" : 5,
			// Only set true when a proxy in front of the app sets the header,
			// because it is trivially forged.
			"trustForwardedFor" : false,
			// Off until a mail layer exists and SMTP is configured.
			"sendNotifications" : true
		};

		routes = [ { pattern : "/:action?/:id?", handler : "Admin" } ];
	}

	function onLoad(){
		// Ahead of Pages, so /contact reaches the form even if a page uses that
		// slug; behind Blog, which claims a narrower prefix.
		wirebox
			.getInstance( "ContentResolverRegistry@core" )
			.register( "ContactContentResolver@contact", 60 );

		wirebox
			.getInstance( "SiteNavigationRegistry@core" )
			.register( "ContactNavigationProvider@contact", 60 );

		wirebox
			.getInstance( "LinkTargetRegistry@core" )
			.register( "ContactLinkTargetProvider@contact", 60 );

		wirebox
			.getInstance( "ShortcodeRegistry@core" )
			.register(
				tag         = "contact-form",
				id          = "ContactShortcode@contact",
				description = "Embeds this site's contact form: [contact-form]"
			);

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
		wirebox.getInstance( "ContentResolverRegistry@core" ).unregister( "ContactContentResolver@contact" );
		wirebox.getInstance( "SiteNavigationRegistry@core" ).unregister( "ContactNavigationProvider@contact" );
		wirebox.getInstance( "LinkTargetRegistry@core" ).unregister( "ContactLinkTargetProvider@contact" );
		wirebox.getInstance( "ShortcodeRegistry@core" ).unregister( "contact-form" );
		wirebox.getInstance( "AdminNavigationRegistry@core" ).unregister( "/admin/contact" );
	}

}
