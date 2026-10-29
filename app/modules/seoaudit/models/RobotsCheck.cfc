/**
 * `<meta name="robots">`.
 *
 * `noindex` is the single most consequential tag on a page: it removes the page
 * from search results entirely, and nothing about the page looks wrong. A
 * reader sees normal content, the title and description are fine, the canonical
 * agrees — and the page gets no traffic at all.
 *
 * This CMS has an explicit `robotsIndex` switch, so a `noindex` can be
 * deliberate; a staging tenant, a thank-you page after a form, a print variant.
 * That is why it is a **warning** rather than an error. It is reported on every
 * page that carries it, because "this page is excluded from search" is worth
 * saying out loud each time somebody reads the report, and the only way for it
 * to stop appearing is for somebody to decide it is correct.
 *
 * `nofollow` is a notice. It stops link equity flowing out of the page, which
 * matters to a site's internal linking but costs this page nothing.
 *
 * ## What this does not look at
 *
 * `robots.txt`, and the `X-Robots-Tag` header. Both can exclude a page just as
 * effectively, and neither is in the markup — the header is thrown away by the
 * fetcher and `robots.txt` is a site-level question, not a page-level one.
 * Worth adding; a different check.
 */
component singleton accessors="true" {

	this.ID = "robots";

	array function inspect( required any document, required struct context ){
		var directives = lCase( arguments.document.metaByName( "robots" ) );

		if ( !len( directives ) ) {
			return [];
		}

		var found = [];

		// `listFindNoCase` on a comma list, because the value is a comma list —
		// `index, nofollow`. A substring test would read `noindexing` or a
		// hypothetical `noindex-images` as `noindex`.
		var values = listToArray( directives, "," ).map( ( value ) => trim( value ) );

		if ( values.findNoCase( "noindex" ) || values.findNoCase( "none" ) ) {
			found.append( {
				"checkId"  : "robots.noindex",
				"severity" : "warning",
				"message"  : "This page asks search engines not to index it, so it will not appear in results at all.",
				"detail"   : "meta robots: #arguments.document.metaByName( 'robots' )#"
					& ". Deliberate for a thank-you or print page; check the page's Indexing switch if it is not."
			} );
		}

		if ( values.findNoCase( "nofollow" ) || values.findNoCase( "none" ) ) {
			found.append( {
				"checkId"  : "robots.nofollow",
				"severity" : "notice",
				"message"  : "This page tells search engines not to follow its links.",
				"detail"   : "meta robots: #arguments.document.metaByName( 'robots' )#"
			} );
		}

		return found;
	}

}
