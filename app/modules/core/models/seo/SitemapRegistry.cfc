/**
 * What a site offers a search engine, collected from the modules that own it.
 *
 * The same seam as ContentResolverRegistry and SiteNavigationRegistry, for the
 * same reason: Core serves `/sitemap.xml`, but Core must not know that Pages or
 * Blog exist. It asks every registered provider what it publishes, and a module
 * answers for its own content.
 *
 * A provider is any object with:
 *
 *     array getSitemapEntries( numeric siteId )
 *
 * returning structs, not entities:
 *
 *     { path : "about/team", lastModified : <date>, changeFrequency : "monthly", priority : 0.6 }
 *
 * Only `path` is required. A provider must return **published** content only —
 * a draft in a sitemap is an invitation to index a page that 404s.
 */
component singleton accessors="true" {

	property name="wirebox" inject="wirebox";
	property name="log"     inject="logbox:logger:{this}";

	// Sitemaps.org caps a single sitemap file at 50,000 URLs. Far beyond
	// anything this CMS will produce soon, but a cap that exists is a cap that
	// cannot be exceeded by accident.
	variables.MAX_ENTRIES = 50000;

	variables.FREQUENCIES = "always,hourly,daily,weekly,monthly,yearly,never";

	function init(){
		variables.providers = [];
		return this;
	}

	/**
	 * @id       WireBox id, resolved lazily so module load order does not matter.
	 * @priority Lower is asked first.
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
	 * Every URL a site publishes, normalised and de-duplicated.
	 *
	 * A provider that fails is skipped with a warning rather than taking the
	 * sitemap down: a sitemap missing one module's content is a smaller problem
	 * than a sitemap that 500s, which a crawler may retry for days.
	 *
	 * De-duplication is by path, first provider winning. Two modules claiming
	 * one URL is a routing bug, but listing it twice would additionally be an
	 * invalid sitemap.
	 */
	array function getEntriesFor( required numeric siteId ){
		var seen    = {};
		var entries = [];

		for ( var entry in variables.providers ) {
			if ( entries.len() >= variables.MAX_ENTRIES ) {
				break;
			}

			try {
				var provider = wirebox.getInstance( entry.id );

				for ( var item in provider.getSitemapEntries( arguments.siteId ) ) {
					if ( entries.len() >= variables.MAX_ENTRIES ) {
						log.warn( "Sitemap for site [#arguments.siteId#] hit the #variables.MAX_ENTRIES# URL cap; the rest were dropped." );
						break;
					}

					var normalised = normalise( item );

					if ( structKeyExists( seen, normalised.path ) ) {
						continue;
					}

					seen[ normalised.path ] = true;
					entries.append( normalised );
				}
			} catch ( any e ) {
				log.warn( "Sitemap provider [#entry.id#] failed: #e.message#" );
			}
		}

		return entries;
	}

	/**
	 * One provider's entry, reduced to something safe to write into XML.
	 *
	 * Explicit key checks rather than `?:` throughout: ColdFusion's elvis
	 * operator treats a falsy value as absent, and a priority of 0 — a page a
	 * site deliberately ranks last — would silently become the default.
	 */
	private struct function normalise( required struct item ){
		var path = reReplace( trim( arguments.item.path ?: "" ), "^/+|/+$", "", "all" );

		var frequency = structKeyExists( arguments.item, "changeFrequency" )
			? lCase( trim( arguments.item.changeFrequency ) )
			: "";

		var priority = structKeyExists( arguments.item, "priority" )
			? val( arguments.item.priority )
			: 0.5;

		return {
			"path"            : path,
			"lastModified"    : structKeyExists( arguments.item, "lastModified" ) && isDate( arguments.item.lastModified )
				? arguments.item.lastModified
				: "",
			// Anything not in the spec's vocabulary is dropped rather than
			// written out, because a sitemap with an invalid value is rejected
			// wholesale by some crawlers.
			"changeFrequency" : listFindNoCase( variables.FREQUENCIES, frequency ) ? frequency : "",
			"priority"        : max( 0, min( 1, priority ) )
		};
	}

}
