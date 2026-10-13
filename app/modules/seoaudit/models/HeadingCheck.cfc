/**
 * Headings.
 *
 * The reason this module reads rendered HTML rather than the database.
 *
 * A page's `<h1>` can come from two places in this CMS: the theme emits one
 * when the page's `showHeading` is on, and an author may write their own in the
 * content — a combination deliberately allowed, because some pages want a
 * hand-built heading. Nothing in `pages` is wrong when both happen. The page
 * simply has two first-level headings, and only the output shows it.
 *
 * A skipped level (h1 straight to h3) is a notice, not a warning: it is an
 * outline problem that matters to a screen reader and barely at all to a
 * crawler, and flagging it loudly would bury the findings that cost traffic.
 */
component singleton accessors="true" {

	this.ID = "heading";

	array function inspect( required any document, required struct context ){
		var headings = arguments.document.headings();
		var found    = [];
		var firsts   = headings.filter( ( h ) => h.level == 1 );

		if ( !firsts.len() ) {
			found.append( {
				"checkId"  : "heading.noH1",
				"severity" : "error",
				"message"  : "This page has no h1, so nothing states what it is about.",
				"detail"   : ""
			} );
		}

		if ( firsts.len() > 1 ) {
			found.append( {
				"checkId"  : "heading.multipleH1",
				"severity" : "error",
				"message"  : "This page has #firsts.len()# h1 headings. Turn off ""Show heading"" on the page if the content provides its own.",
				"detail"   : firsts.map( ( h ) => h.text ).toList( " | " )
			} );
		}

		// Walked in document order: the sequence is the finding, so this
		// cannot be done by counting levels.
		var previous = 0;

		for ( var heading in headings ) {
			if ( previous && heading.level > previous + 1 ) {
				found.append( {
					"checkId"  : "heading.skippedLevel",
					"severity" : "notice",
					"message"  : "Heading levels jump from h#previous# to h#heading.level#, which breaks the page outline.",
					"detail"   : heading.text
				} );
			}

			previous = heading.level;
		}

		// An h1 that disagrees with the title is not automatically wrong — they
		// serve different readers — but an h1 that is empty is.
		if ( firsts.len() == 1 && !len( firsts[ 1 ].text ) ) {
			found.append( {
				"checkId"  : "heading.emptyH1",
				"severity" : "error",
				"message"  : "The h1 is empty.",
				"detail"   : ""
			} );
		}

		return found;
	}

}
