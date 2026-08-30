/**
 * Will — per-site will questionnaire.
 *
 * Public wizard at /will. One POST writes will_submission plus any repeating
 * groups. Admin list and detail live at /admin/will.
 */
component {

	this.title       = "Will";
	this.author      = "myCFCMS";
	this.description = "Per-site will questionnaire submissions.";
	this.version     = "1.0.0";

	this.cfmapping      = "will";
	this.modelNamespace = "will";
	this.autoMapModels  = true;

	this.entryPoint        = "admin/will";
	this.inheritEntryPoint = false;

	this.dependencies = [ "core" ];

	function configure(){
		settings = {
			"basePath"          : "will",
			"thankYouSegment"   : "thank-you",
			"honeypotField"     : "website",
			"formTitle"         : "Create your will",
			"trustForwardedFor" : false,
			// Off for this form only. Contact is unchanged. Set true to show
			// and enforce reCAPTCHA again.
			"requireRecaptcha"  : false
		};

		routes = [ { pattern : "/:action?/:id?", handler : "Admin" } ];
	}

	function onLoad(){
		// Ahead of Pages (100), so /will is this wizard even if a page uses that slug.
		wirebox
			.getInstance( "ContentResolverRegistry@core" )
			.register( "WillContentResolver@will", 55 );

		wirebox
			.getInstance( "SiteNavigationRegistry@core" )
			.register( "WillNavigationProvider@will", 55 );

		wirebox
			.getInstance( "LinkTargetRegistry@core" )
			.register( "WillLinkTargetProvider@will", 55 );

		wirebox
			.getInstance( "AdminNavigationRegistry@core" )
			.register(
				label      = "Wills",
				href       = "/admin/will",
				permission = "will.view",
				order      = 44,
				group      = "Modules"
			);
	}

	function onUnload(){
		wirebox.getInstance( "ContentResolverRegistry@core" ).unregister( "WillContentResolver@will" );
		wirebox.getInstance( "SiteNavigationRegistry@core" ).unregister( "WillNavigationProvider@will" );
		wirebox.getInstance( "LinkTargetRegistry@core" ).unregister( "WillLinkTargetProvider@will" );
		wirebox.getInstance( "AdminNavigationRegistry@core" ).unregister( "/admin/will" );
	}

}
