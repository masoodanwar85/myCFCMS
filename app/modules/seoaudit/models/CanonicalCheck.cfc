/**
 * The canonical URL.
 *
 * A canonical tag naming a *different* URL tells a search engine "do not index
 * this page, index that one instead". When that is accidental it is the most
 * damaging single fault on this list — the page disappears from results and
 * nothing on the page looks wrong — so it is an error, and the detail names
 * both URLs so the mistake is obvious at a glance.
 *
 * ## What the comparison ignores, and why it must
 *
 * A trailing slash and case, because neither means anything to a crawler.
 *
 * And **the scheme**. `SeoService` builds a canonical from the scheme of the
 * request that rendered the page, and the audit fetches over plain HTTP on
 * loopback — so a site served as `https` in public emits
 * `http://example.test/about` to the crawler. Comparing whole URLs reported
 * every page of every site as having a mismatched canonical: an error-severity
 * finding, on everything, caused entirely by how the audit fetches. That is the
 * worst kind of false positive, because it makes the whole report ignorable.
 *
 * The host is still compared, because a canonical pointing at a *different
 * site* is the real fault this check exists for.
 */
component singleton accessors="true" {

	this.ID = "canonical";

	array function inspect( required any document, required struct context ){
		var canonical = arguments.document.linkByRel( "canonical" );
		var expected  = trim( arguments.context.absoluteUrl ?: "" );

		if ( !len( canonical ) ) {
			return [ {
				"checkId"  : "canonical.missing",
				"severity" : "notice",
				"message"  : "No canonical URL. Harmless until the same content answers on more than one address.",
				"detail"   : ""
			} ];
		}

		// Nothing to compare against: the site has no primary domain, which is
		// reported once for the site rather than on every page.
		if ( !len( expected ) ) {
			return [];
		}

		if ( normalise( canonical ) != normalise( expected ) ) {
			return [ {
				"checkId"  : "canonical.mismatch",
				"severity" : "error",
				"message"  : "The canonical URL points somewhere else, which asks search engines not to index this page.",
				"detail"   : "This page: #expected# — canonical says: #canonical#"
			} ];
		}

		return [];
	}

	/**
	 * Host and path only, lowercased, without a trailing slash. The scheme is
	 * stripped rather than compared — see the note above.
	 */
	private string function normalise( required string url ){
		var clean = lCase( trim( arguments.url ) );

		clean = reReplaceNoCase( clean, "^https?://", "", "one" );

		return reReplace( clean, "/+$", "" );
	}

}
