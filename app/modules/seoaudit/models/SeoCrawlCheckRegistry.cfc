/**
 * Checks that need the whole crawl, not one page.
 *
 * A second registry rather than a second method on the first, because the
 * contract is genuinely different: a per-page check is handed a parsed document
 * and answers about it, and cannot see the other ninety-nine pages. "Two pages
 * share a title" and "this link goes to a 404" are not questions about a
 * document at all — they are questions about the set.
 *
 * A check is any object with:
 *
 *     array function inspect( array pages, struct context )
 *
 * where each entry of `pages` is what the crawl collected:
 *
 *     { path, statusCode, title, description, canonical, links : [ paths ],
 *       seeded : boolean }
 *
 * `links` holds only internal, auditable paths — external links are not
 * fetched, so nothing here can say whether they work. `seeded` is whether the
 * URL came from the sitemap or was discovered by following a link.
 *
 * Findings carry their own `path`, because a crawl check attributes its finding
 * to a page it chooses: a broken link is reported against the page that
 * contains it, not the page that is missing.
 */
component singleton accessors="true" {

	property name="wirebox" inject="wirebox";
	property name="log"     inject="logbox:logger:{this}";

	this.SEVERITIES = "error,warning,notice";

	function init(){
		variables.checks = [];
		return this;
	}

	function register( required string id, numeric priority = 100 ){
		for ( var existing in variables.checks ) {
			if ( existing.id == arguments.id ) {
				return this;
			}
		}

		variables.checks.append( { "id" : arguments.id, "priority" : arguments.priority } );
		variables.checks.sort( ( a, b ) => a.priority - b.priority );

		return this;
	}

	function unregister( required string id ){
		var wanted = arguments.id;

		variables.checks = variables.checks.filter( ( entry ) => entry.id != wanted );

		return this;
	}

	array function getRegistered(){
		return variables.checks.map( ( entry ) => entry.id );
	}

	/**
	 * Every crawl-wide finding. A check that throws is skipped with a warning
	 * rather than discarding the per-page findings the run already has.
	 */
	array function inspect( required array pages, required struct context ){
		var findings = [];

		for ( var entry in variables.checks ) {
			try {
				var check = wirebox.getInstance( entry.id );

				for ( var finding in check.inspect( arguments.pages, arguments.context ) ) {
					findings.append( normalise( finding ) );
				}
			} catch ( any e ) {
				log.warn( "SEO crawl check [#entry.id#] failed: #e.message# #e.detail ?: ''#" );
			}
		}

		return findings;
	}

	private struct function normalise( required struct finding ){
		var severity = lCase( trim( arguments.finding.severity ?: "" ) );

		return {
			"path"     : arguments.finding.path ?: "",
			"checkId"  : left( trim( arguments.finding.checkId ?: "unknown" ), 64 ),
			"severity" : listFindNoCase( this.SEVERITIES, severity ) ? severity : "notice",
			"message"  : left( trim( arguments.finding.message ?: "" ), 500 ),
			"detail"   : left( trim( arguments.finding.detail ?: "" ), 1000 )
		};
	}

}
