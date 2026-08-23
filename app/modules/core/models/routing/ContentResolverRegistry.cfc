/**
 * How Core routes a URL to content it knows nothing about.
 *
 * Core owns the front controller, but Core must not depend on Pages, Blog or
 * News. So it does not ask "which page is at this path?" — it asks every
 * registered resolver "can any of you answer for this path?", and a feature
 * module supplies the answer.
 *
 * A module registers itself in its own ModuleConfig, which means installing or
 * removing a module changes what the site can serve without a line of Core
 * changing:
 *
 *     binder.getInjector()
 *           .getInstance( "ContentResolverRegistry@core" )
 *           .register( "PageContentResolver@pages", 100 );
 *
 * A resolver is any object with:
 *
 *     struct|null resolveContent( numeric siteId, string path )
 *
 * returning null when it does not recognise the path, or:
 *
 *     {
 *         view            : "page",   // a view the theme must provide
 *         args            : { ... },  // passed to that view
 *         title           : "About",  // document title
 *         metaDescription : "...",
 *         navigation      : [ ... ],  // optional, for the layout
 *         statusCode      : 200
 *     }
 */
component singleton accessors="true" {

	property name="wirebox" inject="wirebox";
	property name="log"     inject="logbox:logger:{this}";

	function init(){
		// { id : <wirebox id>, priority : <numeric> }, kept in priority order.
		variables.resolvers = [];
		return this;
	}

	/**
	 * Register a resolver.
	 *
	 * @id       WireBox id, e.g. `PageContentResolver@pages`. Resolved lazily so
	 *           module load order does not matter.
	 * @priority Lower runs first. Give a catch-all a high number so a module
	 *           that claims a specific prefix can answer ahead of it.
	 */
	function register( required string id, numeric priority = 100 ){
		for ( var existing in variables.resolvers ) {
			if ( existing.id == arguments.id ) {
				return this;
			}
		}

		variables.resolvers.append( { "id" : arguments.id, "priority" : arguments.priority } );
		variables.resolvers.sort( ( a, b ) => a.priority - b.priority );

		return this;
	}

	function unregister( required string id ){
		var wanted = arguments.id;

		variables.resolvers = variables.resolvers.filter( ( entry ) => entry.id != wanted );

		return this;
	}

	array function getRegistered(){
		return variables.resolvers.map( ( entry ) => entry.id );
	}

	/**
	 * Ask each resolver in turn; the first answer wins.
	 *
	 * @return The resolution struct, or null when nothing claims the path.
	 */
	function resolve( required numeric siteId, required string path ){
		for ( var entry in variables.resolvers ) {
			var resolver = wirebox.getInstance( entry.id );
			var result   = resolver.resolveContent( arguments.siteId, arguments.path );

			if ( !isNull( result ) ) {
				return normalize( result );
			}
		}

		return;
	}

	/**
	 * Fill in the parts a resolver may reasonably leave out, so the front
	 * controller and the themes can rely on every key being present.
	 */
	private struct function normalize( required struct resolution ){
		var result = arguments.resolution;

		result.view            = result.view ?: "page";
		result.args            = result.args ?: {};
		result.title           = result.title ?: "";
		result.metaDescription = result.metaDescription ?: "";
		result.navigation      = result.navigation ?: [];
		result.statusCode      = result.statusCode ?: 200;

		return result;
	}

}
