/**
 * Contributes a site's top-level pages to its public navigation.
 *
 * Core asks for this without knowing what a page is; this module answers
 * without knowing what a menu is used for.
 */
component singleton accessors="true" {

	property name="pageService" inject="PageService@pages";

	/**
	 * Published top-level pages, in the order an editor arranged them.
	 */
	array function getNavigationItems( required numeric siteId ){
		return pageService
			.getRootPages( arguments.siteId )
			.filter( ( page ) => page.isPublished() )
			.map( ( page ) => {
				return {
					"label" : page.getTitle(),
					"href"  : "/" & page.getPath(),
					"order" : page.getSortOrder()
				};
			} );
	}

}
