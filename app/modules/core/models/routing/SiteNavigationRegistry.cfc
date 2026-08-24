/**
 * A site's public navigation, contributed by modules.
 *
 * Navigation is site chrome, not content. Before this existed it was supplied
 * by whichever content resolver answered the URL, which meant the menu appeared
 * on pages and vanished on the blog — the module that served the request was
 * also the only one that could describe the site.
 *
 * Now Core asks every registered provider, independently of what served the
 * page, so the menu is the same on a page, a blog post, and a 404.
 *
 * A provider is any object with:
 *
 *     array getNavigationItems( numeric siteId )
 *
 * returning structs, not entities:
 *
 *     { label : "About", href : "/about", order : 1 }
 *
 * Structs on purpose. A theme should not have to know that one item is a Page
 * and another is a module's landing link, and a module contributing a menu
 * entry should not have to invent an entity to do it.
 */
component singleton accessors="true" {

	property name="wirebox" inject="wirebox";
	property name="log"     inject="logbox:logger:{this}";

	function init(){
		variables.providers = [];
		return this;
	}

	/**
	 * @id       WireBox id, resolved lazily so module load order does not matter.
	 * @priority Lower is asked first. Ties between items are broken by each
	 *           item's own `order`, then its label.
	 */
	function register( required string id, numeric priority = 100 ){
		for ( var existing in variables.providers ) {
			if ( existing.id == arguments.id ) {
				return this;
			}
		}

		variables.providers.append( { "id" : arguments.id, "priority" : arguments.priority } );
		variables.providers.sort( ( a, b ) => a.priority - b.priority );

		return this;
	}

	function unregister( required string id ){
		var wanted = arguments.id;

		variables.providers = variables.providers.filter( ( entry ) => entry.id != wanted );

		return this;
	}

	array function getRegistered(){
		return variables.providers.map( ( entry ) => entry.id );
	}

	/**
	 * The whole menu for a site.
	 *
	 * A provider that fails is skipped with a warning rather than taking the
	 * page down: a broken menu is a poor experience, but a blank site is worse.
	 */
	array function getNavigationFor( required numeric siteId ){
		var items = [];

		for ( var entry in variables.providers ) {
			try {
				var provider = wirebox.getInstance( entry.id );

				for ( var item in provider.getNavigationItems( arguments.siteId ) ) {
					// Explicit key checks rather than `?:`. ColdFusion's elvis
					// operator treats a falsy value as absent, so an item with
					// `order` 0 — the first page in a menu — would silently take
					// the default and sort last.
					items.append( {
						"label" : structKeyExists( item, "label" ) ? item.label : "",
						"href"  : structKeyExists( item, "href" ) ? item.href : "/",
						"order" : structKeyExists( item, "order" ) ? val( item.order ) : 100
					} );
				}
			} catch ( any e ) {
				log.warn( "Navigation provider [#entry.id#] failed: #e.message#" );
			}
		}

		items.sort( ( a, b ) => {
			if ( a.order != b.order ) {
				return a.order < b.order ? -1 : 1;
			}
			return compareNoCase( a.label, b.label );
		} );

		return items;
	}

}
