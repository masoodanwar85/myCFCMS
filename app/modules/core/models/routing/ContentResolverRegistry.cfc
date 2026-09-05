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
 * A resolver describes *content*, not chrome. The site's navigation comes from
 * SiteNavigationRegistry instead, so the menu does not change depending on which
 * module served the URL.
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
 *         statusCode      : 200,
 *
 *         // optional, for SEO; see normalize() for the defaults
 *         canonicalPath   : "about",      // the one URL this should be indexed at
 *         robots          : "noindex",    // per-page directive
 *         image           : "/media/...", // social preview
 *         contentType     : "article",    // Open Graph type
 *         publishedAt     : <date>,
 *         modifiedAt      : <date>
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
				return normalize( result, arguments.path );
			}
		}

		return;
	}

	/**
	 * Route a form submission to whichever resolver claims the path.
	 *
	 * Public content that accepts input — a contact form — needs somewhere for
	 * the POST to go. Adding a public route per module would mean each one
	 * reaching into the application router, and ordering between them would
	 * decide who won.
	 *
	 * So a resolver may optionally implement:
	 *
	 *     struct|null handleSubmission( numeric siteId, string path, struct formData )
	 *
	 * It receives the submitted values as a plain struct — not the event, not
	 * the request — so a module still knows nothing about HTTP. It returns a
	 * resolution to render, optionally carrying `redirectTo` for the
	 * redirect-after-post that stops a refresh resubmitting.
	 *
	 * @return The resolution, or null when nothing handles submissions here.
	 */
	function resolveSubmission(
		required numeric siteId,
		required string path,
		required struct formData
	){
		for ( var entry in variables.resolvers ) {
			var resolver = wirebox.getInstance( entry.id );

			if ( !structKeyExists( resolver, "handleSubmission" ) ) {
				continue;
			}

			var result = resolver.handleSubmission( arguments.siteId, arguments.path, arguments.formData );

			if ( !isNull( result ) ) {
				return normalize( result, arguments.path );
			}
		}

		return;
	}

	/**
	 * Fill in the parts a resolver may reasonably leave out, so the front
	 * controller and the themes can rely on every key being present.
	 *
	 * @requestedPath The path this resolution answers, used as the default
	 *                canonical. It is defaulted **here** rather than downstream
	 *                because an empty `canonicalPath` is a meaningful answer —
	 *                it names the site root — and anything checking `len()`
	 *                further along would read that as "unspecified" and quietly
	 *                canonicalise the home page to `/home`.
	 */
	private struct function normalize( required struct resolution, string requestedPath = "" ){
		var result = arguments.resolution;

		result.view            = result.view ?: "page";

		// A theme template to render through instead of the view, named by the
		// resolver. Empty means the view, which is what every resolver that has
		// never heard of templates returns.
		result.template        = result.template ?: "";
		result.args            = result.args ?: {};
		result.title           = result.title ?: "";
		result.metaDescription = result.metaDescription ?: "";
		result.statusCode      = result.statusCode ?: 200;
		result.redirectTo      = result.redirectTo ?: "";

		// SEO. All optional: a resolver that says nothing gets sensible
		// defaults from SeoService and the site's own settings, so adding these
		// did not oblige every existing resolver to change.
		//
		// `canonicalPath` matters most. A module that can serve one piece of
		// content at more than one URL — a blog post reachable through a
		// category, say — names the one address it wants indexed here.
		result.canonicalPath   = structKeyExists( result, "canonicalPath" )
			? result.canonicalPath
			: arguments.requestedPath;
		result.robots          = result.robots ?: "";
		result.image           = result.image ?: "";
		result.contentType     = result.contentType ?: "";
		result.publishedAt     = result.publishedAt ?: "";
		result.modifiedAt      = result.modifiedAt ?: "";
		result.keywords        = result.keywords ?: "";
		result.ogTitle         = result.ogTitle ?: "";
		result.ogDescription   = result.ogDescription ?: "";
		result.twitterCard     = result.twitterCard ?: "";

		// Raw markup a module has already decided its author was allowed to
		// write. Core carries it and never inspects it — the permission check
		// belongs with whoever owns the content.
		result.headMarkup      = result.headMarkup ?: "";
		result.bodyMarkup      = result.bodyMarkup ?: "";
		result.jsonLd          = result.jsonLd ?: "";

		return result;
	}

}
