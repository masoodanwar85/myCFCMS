/**
 * Pages that describe themselves identically.
 *
 * Two pages with the same `<title>` compete with each other in results for the
 * same query, and a search engine picks one — usually not the one you wanted.
 * It is reported on **every** page in the group rather than on one of them,
 * because there is no basis for calling any single one the duplicate; whoever
 * fixes it needs to see all the addresses involved.
 *
 * ## Why titles are a warning and descriptions a notice
 *
 * A shared title is a ranking problem: the pages dilute each other. A shared
 * description is a presentation problem — the results look repetitive — and
 * Google frequently rewrites the description anyway. Ranking them equally would
 * overstate the second.
 *
 * ## What is deliberately not reported
 *
 * Pages with the same *content*. Detecting near-duplicate bodies needs
 * shingling or hashing and a judgement about how similar is too similar, and
 * the common CMS cause — one page reachable at two URLs — is already covered by
 * the canonical check. Identical titles catch the realistic case: a stub page
 * copied nine times and never retitled.
 */
component singleton accessors="true" {

	this.ID = "duplicate";

	array function inspect( required array pages, required struct context ){
		var found = [];

		found.append( group( arguments.pages, "title", "title", "warning" ), true );
		found.append( group( arguments.pages, "description", "description", "notice" ), true );

		return found;
	}

	/**
	 * Group the crawl by one field and report any value shared by more than one
	 * page.
	 *
	 * Keyed on the lowercased, whitespace-collapsed value: two titles differing
	 * only in case or spacing are the same title to a reader and to a search
	 * engine, and reporting them as distinct would miss the finding.
	 */
	private array function group(
		required array pages,
		required string field,
		required string label,
		required string severity
	){
		var groups = {};

		for ( var page in arguments.pages ) {
			if ( page.statusCode != 200 ) {
				continue;
			}

			var value = trim( page[ arguments.field ] ?: "" );

			// A missing title is its own finding, reported per page. Grouping
			// the empties would say "nine pages share the same blank title",
			// which is true and unhelpful.
			if ( !len( value ) ) {
				continue;
			}

			var key = lCase( reReplace( value, "\s+", " ", "all" ) );

			if ( !structKeyExists( groups, key ) ) {
				groups[ key ] = { "value" : value, "paths" : [] };
			}

			groups[ key ].paths.append( page.path );
		}

		var found = [];

		for ( var key in groups ) {
			var entry = groups[ key ];

			if ( entry.paths.len() < 2 ) {
				continue;
			}

			for ( var path in entry.paths ) {
				// "Also on" means the others, not this one. Captured into a
				// local first because inside the closure `arguments` is the
				// closure's own scope, not this function's.
				var current = path;
				var others  = entry.paths
					.filter( ( candidate ) => candidate != current )
					.map( ( candidate ) => len( candidate ) ? "/" & candidate : "/" );

				found.append( {
					"path"     : path,
					"checkId"  : "duplicate." & arguments.field,
					"severity" : arguments.severity,
					"message"  : "#entry.paths.len()# pages share this #arguments.label#, so they compete with each other in results.",
					// Every other address in the group, so the person fixing it
					// can see what they are reconciling without running the
					// audit again.
					"detail"   : """" & entry.value & """ — also on: " & others.toList( ", " )
				} );
			}
		}

		return found;
	}

}
