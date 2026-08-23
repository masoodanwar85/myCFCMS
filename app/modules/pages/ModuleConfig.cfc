/**
 * Pages — the first feature module.
 *
 * Owns the `pages` table and nothing else. It depends on Core (for tenancy,
 * users and authorisation) and on no other feature module; Core, in turn, knows
 * nothing about it. Blog, News and Contact will follow this same shape, which
 * is why this module is deliberately unremarkable.
 *
 * Group 3 delivers the data model and the service layer. It registers no
 * routes and renders nothing — pages become reachable in a browser when the
 * routing and theme layer lands.
 */
component {

	this.title       = "Pages";
	this.author      = "myCFCMS";
	this.description = "Hierarchical, per-site content pages.";
	this.version     = "1.0.0";

	this.cfmapping      = "pages";
	this.modelNamespace = "pages";
	this.autoMapModels  = true;

	// No entry point yet: this module serves no URLs of its own in Group 3.
	this.entryPoint        = "";
	this.inheritEntryPoint = false;

	this.dependencies = [ "core" ];

	function configure(){
		settings = {
			// Site setting key under which a site records its home page.
			// Stored through Core's site settings rather than as a column, so
			// Core needs no knowledge of pages.
			"homePageSettingKey" : "pages.homePageId"
		};

		/**
		 * Announced so later modules — menus, search indexing, cache
		 * invalidation — can react without this module knowing they exist.
		 */
		interceptorSettings = {
			customInterceptionPoints : [
				"onPageCreated",
				"onPageUpdated",
				"onPagePublished",
				"onPageUnpublished",
				"onPageDeleted"
			]
		};
	}

	/**
	 * Tell Core this module can serve URLs.
	 *
	 * Core's front controller asks its registry, not this module, so installing
	 * or removing Pages changes what the site serves without touching Core.
	 * Priority 100 makes this the catch-all: a module claiming a specific
	 * prefix (a blog under /blog, say) registers a lower number and is asked
	 * first.
	 */
	function onLoad(){
		wirebox
			.getInstance( "ContentResolverRegistry@core" )
			.register( "PageContentResolver@pages", 100 );
	}

	function onUnload(){
		wirebox
			.getInstance( "ContentResolverRegistry@core" )
			.unregister( "PageContentResolver@pages" );
	}

}
