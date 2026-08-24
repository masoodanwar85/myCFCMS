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

	// The module serves no public URLs of its own — Core's front controller asks
	// its content resolver instead. It does own its admin screens, so its entry
	// point is the admin area rather than the site root.
	this.entryPoint        = "admin/pages";
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
		routes = [ { pattern : "/:action?/:id?", handler : "Admin" } ];

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

		// Contribute the site's top-level pages to its public menu. Core asks
		// every provider regardless of which module served the request, so the
		// menu is the same on a page, a blog post and a 404.
		wirebox
			.getInstance( "SiteNavigationRegistry@core" )
			.register( "PageNavigationProvider@pages", 10 );

		// And to its sitemap. Same seam again: Core serves /sitemap.xml without
		// knowing that pages exist.
		wirebox
			.getInstance( "SitemapRegistry@core" )
			.register( "PageSitemapProvider@pages", 10 );

		// The module's REST resource. Core builds the conventional routes from
		// this, so `/api/v1/pages` appears without a line changing in the
		// application router.
		wirebox
			.getInstance( "ApiRouteRegistry@core" )
			.resource( name = "pages", module = "pages", handler = "Api", memberActions = "publish,unpublish" );

		// And what a menu item may point at, so an editor can link to this
		// module's content without Core knowing the content exists.
		wirebox
			.getInstance( "LinkTargetRegistry@core" )
			.register( "PageLinkTargetProvider@pages", 10 );

		// Contribute an admin section. The admin shell renders whatever is
		// registered, so it needs no knowledge of this module.
		wirebox
			.getInstance( "AdminNavigationRegistry@core" )
			.register(
				label      = "Pages",
				href       = "/admin/pages",
				permission = "pages.view",
				// First in CMS, and therefore the group's own position.
				order      = 20,
				group      = "CMS"
			);
	}

	function onUnload(){
		wirebox
			.getInstance( "ContentResolverRegistry@core" )
			.unregister( "PageContentResolver@pages" );

		wirebox
			.getInstance( "SiteNavigationRegistry@core" )
			.unregister( "PageNavigationProvider@pages" );

		wirebox
			.getInstance( "SitemapRegistry@core" )
			.unregister( "PageSitemapProvider@pages" );

		wirebox.getInstance( "ApiRouteRegistry@core" ).unregister( "pages" );

		wirebox
			.getInstance( "LinkTargetRegistry@core" )
			.unregister( "PageLinkTargetProvider@pages" );

		wirebox
			.getInstance( "AdminNavigationRegistry@core" )
			.unregister( "/admin/pages" );
	}

}
