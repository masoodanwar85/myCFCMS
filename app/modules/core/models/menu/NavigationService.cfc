/**
 * What the front controller asks for the site's menu.
 *
 * There are now two sources of navigation, and this decides between them.
 *
 *   1. A **curated menu** an editor built, if the site has one.
 *   2. The **module-contributed** navigation from SiteNavigationRegistry —
 *      Pages offering its top-level pages, Blog offering a "Blog" link.
 *
 * Curated wins when it exists and has something in it. Otherwise the automatic
 * navigation stands.
 *
 * That fallback is the whole point of doing it this way. Adding editable menus
 * must not blank the navigation of every site that already exists and has never
 * opened the new screen — a CMS feature that silently removes a client's menu
 * the day it ships is worse than not shipping it. A site keeps the sensible
 * default until somebody deliberately replaces it, and can go back to the
 * default by deleting the menu.
 *
 * Both sources are flattened to the same shape, so a theme written before menus
 * existed keeps working:
 *
 *     { label : "About", href : "/about", target : "", children : [] }
 */
component singleton accessors="true" {

	property name="menus"      inject="MenuService@core";
	property name="registry"   inject="SiteNavigationRegistry@core";
	property name="log"        inject="logbox:logger:{this}";

	/**
	 * The site's navigation, curated if there is one.
	 *
	 * @slug Which menu to prefer. Themes ask for `primary` in the header and
	 *       may ask for `footer` separately.
	 */
	array function getNavigationFor( required numeric siteId, string slug = "primary" ){
		try {
			var curated = menus.getRenderableMenu( arguments.siteId, arguments.slug );

			if ( curated.len() ) {
				return curated.map( ( item ) => toStruct( item ) );
			}
		} catch ( any e ) {
			// A broken menu should cost the site its menu, not its pages.
			log.error( "Reading the [#arguments.slug#] menu for site [#arguments.siteId#] failed: #e.message#" );
		}

		// Only the header falls back. A theme asking for a `footer` menu that
		// nobody has built should get nothing, not a duplicate of the header.
		if ( arguments.slug != "primary" ) {
			return [];
		}

		return registry
			.getNavigationFor( arguments.siteId )
			.map( ( item ) => {
				return {
					"label"    : item.label,
					"href"     : item.href,
					"target"   : "",
					"children" : []
				};
			} );
	}

	/**
	 * Does this site have a curated menu?
	 *
	 * Lets the admin say which of the two a visitor is currently seeing, rather
	 * than leaving an editor to guess why the site does not match the screen.
	 */
	boolean function hasCuratedMenu( required numeric siteId, string slug = "primary" ){
		return menus.getRenderableMenu( arguments.siteId, arguments.slug ).len() > 0;
	}

	/**
	 * A MenuItem and its children as plain structs.
	 *
	 * Structs rather than entities for the same reason SiteNavigationRegistry
	 * uses them: a theme should not have to know that one item came from a
	 * database row and another from a module.
	 */
	private struct function toStruct( required any item ){
		return {
			"label"    : arguments.item.getLabel(),
			"href"     : arguments.item.getHref(),
			"target"   : arguments.item.getTarget() ?: "",
			"external" : arguments.item.isExternal(),
			"children" : arguments.item.getChildren().map( ( child ) => toStruct( child ) )
		};
	}

}
