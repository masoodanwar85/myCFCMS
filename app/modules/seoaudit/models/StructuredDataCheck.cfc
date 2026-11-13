/**
 * JSON-LD structured data.
 *
 * What this is actually worth: structured data is how a page earns a rich
 * result — a star rating, a FAQ accordion, an event date in the listing. It
 * never improves a ranking on its own, which is why none of these findings is
 * an error.
 *
 * ## Why a broken block is worse than no block
 *
 * JSON-LD fails silently. A trailing comma, a smart quote pasted in from a
 * word processor, an unescaped newline inside a string — the block is simply
 * ignored, the page looks completely normal, and nothing anywhere says the
 * markup somebody spent an afternoon on is doing nothing. That is the finding
 * this check exists for, and it is a warning: the author believes they have
 * structured data and they do not.
 *
 * A block with no `@type` is the same mistake one level in. It parses, so no
 * tool complains, and it describes nothing a search engine can use.
 *
 * ## Why `@type` and not a schema validation
 *
 * Checking that a `Product` has an `offers` with a `price` means encoding
 * Google's rich-result requirements, which are long, per-type, and change
 * without notice. A check that is confidently out of date is worse than one
 * that is honestly shallow. `@type` is the one thing every block needs
 * regardless, so that is where this stops.
 *
 * In this CMS a block reaches the page through `jsonLd`, which needs
 * `content.unfiltered` — so the author of a broken block is always somebody
 * trusted, and always somebody who will want to know.
 */
component singleton accessors="true" {

	this.ID = "structuredData";

	array function inspect( required any document, required struct context ){
		var blocks = arguments.document.jsonLdBlocks();

		if ( !blocks.len() ) {
			return [ {
				"checkId"  : "structuredData.missing",
				"severity" : "notice",
				"message"  : "No structured data. The page can still rank; it just cannot earn a rich result.",
				"detail"   : ""
			} ];
		}

		var found = [];

		for ( var i = 1; i <= blocks.len(); i++ ) {
			var block = blocks[ i ];
			var which = blocks.len() > 1 ? "Block #i# of #blocks.len()#" : "The block";

			if ( !len( block ) ) {
				found.append( {
					"checkId"  : "structuredData.invalid",
					"severity" : "warning",
					"message"  : "A structured data script is empty, so it describes nothing.",
					"detail"   : which
				} );

				continue;
			}

			if ( !isJSON( block ) ) {
				found.append( {
					"checkId"  : "structuredData.invalid",
					"severity" : "warning",
					"message"  : "Structured data on this page is not valid JSON, so search engines ignore it entirely.",
					"detail"   : which & ": " & left( block, 200 )
				} );

				continue;
			}

			if ( !hasType( deserializeJSON( block ) ) ) {
				found.append( {
					"checkId"  : "structuredData.noType",
					"severity" : "warning",
					"message"  : "Structured data on this page has no @type, so nothing can tell what it describes.",
					"detail"   : which & ": " & left( block, 200 )
				} );
			}
		}

		return found;
	}

	/**
	 * Whether a parsed block declares a type anywhere it is allowed to.
	 *
	 * Three shapes are all legal JSON-LD and all appear in the wild: one object,
	 * an array of objects, and an object whose `@graph` holds the real list.
	 * Only the top level of each is examined — a nested `author` with its own
	 * `@type` does not make an untyped parent typed, and recursing would find
	 * one and call the block fine.
	 */
	private boolean function hasType( required any parsed ){
		if ( isArray( arguments.parsed ) ) {
			// Every entry, not any: one typed object in a list of five does not
			// make the other four usable.
			return arguments.parsed.len() && !arguments.parsed.filter( ( entry ) => !isTyped( entry ) ).len();
		}

		if ( !isStruct( arguments.parsed ) ) {
			return false;
		}

		if ( structKeyExists( arguments.parsed, "@graph" ) ) {
			return hasType( arguments.parsed[ "@graph" ] );
		}

		return isTyped( arguments.parsed );
	}

	private boolean function isTyped( required any entry ){
		if ( !isStruct( arguments.entry ) ) {
			return false;
		}

		// `structKeyExists`, not `?:` on a bracket lookup: a missing key raises
		// on Adobe rather than resolving to null.
		return structKeyExists( arguments.entry, "@type" )
			&& len( trim( toText( arguments.entry[ "@type" ] ) ) );
	}

	/**
	 * `@type` may be a string or an array of them (`["Person","Author"]`), so
	 * both have to flatten to something `len()` can judge.
	 */
	private string function toText( required any value ){
		if ( isArray( arguments.value ) ) {
			return arguments.value.toList( "," );
		}

		return isSimpleValue( arguments.value ) ? arguments.value : "";
	}

}
