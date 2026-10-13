/**
 * The checks a run applies to each page.
 *
 * The same seam as ContentResolverRegistry and the rest: a check is registered
 * by id and resolved lazily, so a module can contribute a check about its own
 * content without this module knowing that module exists — and removing a
 * module removes its checks.
 *
 * A check is any object with:
 *
 *     array function inspect( any document, struct context )
 *
 * returning zero or more findings:
 *
 *     { checkId : "title.tooLong", severity : "warning",
 *       message : "...", detail : "..." }
 *
 * `severity` is `error`, `warning` or `notice`. Anything else is recorded as a
 * notice rather than dropped, because a finding with an odd severity is still a
 * finding and silently discarding it would hide a real problem behind a typo.
 */
component singleton accessors="true" {

	property name="wirebox" inject="wirebox";
	property name="log"     inject="logbox:logger:{this}";

	this.SEVERITIES = "error,warning,notice";

	function init(){
		variables.checks = [];
		return this;
	}

	/**
	 * @id       WireBox id, resolved lazily so module load order does not matter.
	 * @priority Lower runs first. Only affects the order findings are produced,
	 *           which is the order they are listed under a page.
	 */
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
	 * Every finding for one page.
	 *
	 * A check that throws is skipped with a warning rather than taking the run
	 * down. One broken check costs its own findings; it must not cost the other
	 * eight across every URL on the site.
	 */
	array function inspect( required any document, required struct context ){
		var findings = [];

		for ( var entry in variables.checks ) {
			try {
				var check = wirebox.getInstance( entry.id );

				for ( var finding in check.inspect( arguments.document, arguments.context ) ) {
					findings.append( normalise( finding ) );
				}
			} catch ( any e ) {
				log.warn( "SEO check [#entry.id#] failed on [#arguments.context.path ?: ''#]: #e.message#" );
			}
		}

		return findings;
	}

	private struct function normalise( required struct finding ){
		var severity = lCase( trim( arguments.finding.severity ?: "" ) );

		return {
			"checkId"  : left( trim( arguments.finding.checkId ?: "unknown" ), 64 ),
			"severity" : listFindNoCase( this.SEVERITIES, severity ) ? severity : "notice",
			"message"  : left( trim( arguments.finding.message ?: "" ), 500 ),
			"detail"   : left( trim( arguments.finding.detail ?: "" ), 1000 )
		};
	}

}
