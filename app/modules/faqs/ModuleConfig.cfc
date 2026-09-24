/**
 * FAQs — per-site questions and answers, served as an accordion at /faq.
 *
 * Public URLs, admin screens, navigation and permissions are all registered
 * onto Core's seams. Core does not change to accommodate this module.
 */
component {

	this.title       = "FAQs";
	this.author      = "myCFCMS";
	this.description = "Per-site frequently asked questions, shown as an accordion.";
	this.version     = "1.0.0";

	this.cfmapping      = "faqs";
	this.modelNamespace = "faqs";
	this.autoMapModels  = true;

	this.entryPoint        = "admin/faqs";
	this.inheritEntryPoint = false;

	this.dependencies = [ "core" ];

	function configure(){
		settings = {
			// Public URL the accordion is served at.
			"basePath"        : "faq",
			"pageTitle"       : "FAQs",
			"navigationOrder" : 800
		};

		routes = [ { pattern : "/:action?/:id?", handler : "Admin" } ];
	}

	function onLoad(){
		// Ahead of Pages (100), so /faq reaches this module even if a page
		// uses that slug; behind Contact (60) and Blog (50).
		wirebox
			.getInstance( "ContentResolverRegistry@core" )
			.register( "FaqContentResolver@faqs", 70 );

		wirebox
			.getInstance( "SiteNavigationRegistry@core" )
			.register( "FaqNavigationProvider@faqs", 70 );

		wirebox
			.getInstance( "LinkTargetRegistry@core" )
			.register( "FaqLinkTargetProvider@faqs", 70 );

		wirebox
			.getInstance( "AdminNavigationRegistry@core" )
			.register(
				label      = "FAQs",
				href       = "/admin/faqs",
				permission = "faqs.view",
				order      = 48,
				group      = "Modules"
			);
	}

	function onUnload(){
		wirebox.getInstance( "ContentResolverRegistry@core" ).unregister( "FaqContentResolver@faqs" );
		wirebox.getInstance( "SiteNavigationRegistry@core" ).unregister( "FaqNavigationProvider@faqs" );
		wirebox.getInstance( "LinkTargetRegistry@core" ).unregister( "FaqLinkTargetProvider@faqs" );
		wirebox.getInstance( "AdminNavigationRegistry@core" ).unregister( "/admin/faqs" );
	}

}
