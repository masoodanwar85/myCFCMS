/**
 * Answers Core's routing question on behalf of the Pages module.
 *
 * Core asks "does anything serve this path for this site?" and this replies
 * with a page, or null. That is the entire coupling: Core never imports
 * PageService, and this module never registers a route.
 *
 * It also supplies the navigation and breadcrumb the theme's layout needs,
 * because Core cannot build those without knowing what a page tree is.
 */
component singleton accessors="true" {

	property name="pageService" inject="PageService@pages";

	/**
	 * @siteId The resolved tenant.
	 * @path   Normalised request path, no leading or trailing slash.
	 *         An empty path means the site root.
	 *
	 * @return A content resolution struct, or null when no page serves this path.
	 */
	function resolveContent( required numeric siteId, required string path ){
		var page = len( arguments.path )
			? pageService.getPublishedPageByPath( arguments.siteId, arguments.path )
			: resolveHomePage( arguments.siteId );

		if ( isNull( page ) ) {
			return;
		}

		return {
			"view"            : "page",
			"args"            : {
				"page"       : page,
				"breadcrumb" : pageService.getBreadcrumb( page.getId() )
			},
			"title"           : page.getEffectiveMetaTitle(),
			"metaDescription" : page.getMetaDescription() ?: "",
			"navigation"      : navigationFor( arguments.siteId ),
			"statusCode"      : 200
		};
	}

	/**
	 * The site root.
	 *
	 * A site designates its home page through a site setting. Only a published
	 * one is served: a draft home page must not silently become the front door.
	 */
	private function resolveHomePage( required numeric siteId ){
		var home = pageService.getHomePage( arguments.siteId );

		if ( isNull( home ) || !home.isPublished() ) {
			return;
		}

		return home;
	}

	/**
	 * Top-level published pages, in menu order.
	 */
	private array function navigationFor( required numeric siteId ){
		return pageService
			.getRootPages( arguments.siteId )
			.filter( ( page ) => page.isPublished() );
	}

}
