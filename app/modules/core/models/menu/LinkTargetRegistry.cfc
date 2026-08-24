/**
 * What a menu item is allowed to point at, offered by the modules that own it.
 *
 * The fourth registry on the same principle as ContentResolverRegistry,
 * SiteNavigationRegistry and SitemapRegistry — and the one that makes editable
 * menus possible without Core depending on Pages or Blog.
 *
 * A menu item that links to a page stores `content_type = "pages.page"` and a
 * row id. Core has no idea what that string means. When the menu is rendered it
 * hands the pair back and asks the module for a current address, which is what
 * makes a menu survive an editor renaming a page: the stored link points at the
 * *thing*, and the module knows where the thing lives today.
 *
 * A provider is any object with:
 *
 *     array getLinkTargets( numeric siteId )
 *
 * listing what an editor may choose from:
 *
 *     { type : "pages.page", id : 12, label : "About", path : "about", group : "Pages" }
 *
 * and:
 *
 *     struct|null resolveLinkTarget( numeric siteId, string type, numeric id )
 *
 * answering with `{ label : "About", path : "about" }` for something that still
 * exists, or null for something that does not. Returning null is not an error —
 * it is how a module reports that a page was deleted or unpublished, and the
 * item is dropped from the rendered menu rather than linking to a 404.
 */
component singleton accessors="true" {

	property name="wirebox" inject="wirebox";
	property name="log"     inject="logbox:logger:{this}";

	function init(){
		variables.providers = [];
		return this;
	}

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
	 * Everything an editor can link to, for the admin's picker.
	 *
	 * Grouped by the `group` each provider supplies, so the picker can show
	 * "Pages" and "Blog" as separate optgroups without Core naming either.
	 */
	array function getTargetsFor( required numeric siteId ){
		var targets = [];

		for ( var entry in variables.providers ) {
			try {
				var provider = wirebox.getInstance( entry.id );

				for ( var target in provider.getLinkTargets( arguments.siteId ) ) {
					targets.append( {
						"type"  : target.type ?: "",
						"id"    : val( target.id ?: 0 ),
						"label" : target.label ?: "",
						"path"  : reReplace( target.path ?: "", "^/+", "" ),
						"group" : target.group ?: "Content"
					} );
				}
			} catch ( any e ) {
				// A module that cannot list its content should not stop an
				// editor from managing the rest of the menu.
				log.warn( "Link target provider [#entry.id#] failed: #e.message#" );
			}
		}

		return targets;
	}

	/**
	 * Where one stored link points today.
	 *
	 * @return `{ label, path }`, or null when nothing owns this any more.
	 */
	function resolve( required numeric siteId, required string type, required numeric id ){
		for ( var entry in variables.providers ) {
			try {
				var provider = wirebox.getInstance( entry.id );
				var resolved = provider.resolveLinkTarget( arguments.siteId, arguments.type, arguments.id );

				if ( !isNull( resolved ) ) {
					return {
						"label" : resolved.label ?: "",
						"path"  : reReplace( resolved.path ?: "", "^/+", "" )
					};
				}
			} catch ( any e ) {
				log.warn( "Link target provider [#entry.id#] failed to resolve [#arguments.type#/#arguments.id#]: #e.message#" );
			}
		}

		return;
	}

}
