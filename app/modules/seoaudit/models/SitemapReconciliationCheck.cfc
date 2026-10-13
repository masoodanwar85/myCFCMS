/**
 * Where the sitemap and the site disagree.
 *
 * The run already collects both halves and the comparison is free, which turns
 * two silent gaps into findings:
 *
 *   - **In the sitemap, linked from nowhere.** The page is advertised to search
 *     engines but a visitor cannot reach it by clicking. Crawlers follow links
 *     to judge what a site considers important, so an orphan ranks poorly
 *     however prominently the sitemap lists it — and it is usually an accident:
 *     a page removed from a menu and never unpublished.
 *
 *   - **Linked and working, absent from the sitemap.** Often deliberate. A
 *     thank-you page, a legal notice, anything public but not worth a crawler's
 *     budget — `PageSitemapProvider` honours an editor's "exclude from
 *     sitemap" and skips anything marked `noindex`. So this is a notice, and
 *     the message says it may be intentional rather than implying a mistake.
 *
 * ## The home page is excluded from the orphan check
 *
 * It is reachable by definition — it is what the bare domain serves — and
 * nothing needs to link to it for a crawler to find it. Including it would
 * produce a finding on every site whose theme has no explicit link home.
 */
component singleton accessors="true" {

	this.ID = "sitemap";

	array function inspect( required array pages, required struct context ){
		var found    = [];
		var linkedTo = {};

		// Every internal target anybody linked to, from a page that rendered.
		for ( var page in arguments.pages ) {
			if ( page.statusCode != 200 ) {
				continue;
			}

			for ( var target in page.links ) {
				linkedTo[ target ] = true;
			}
		}

		for ( var page in arguments.pages ) {
			if ( page.statusCode != 200 ) {
				continue;
			}

			var isLinked = structKeyExists( linkedTo, page.path );

			if ( page.seeded && !isLinked && len( page.path ) ) {
				found.append( {
					"path"     : page.path,
					"checkId"  : "sitemap.orphan",
					"severity" : "warning",
					"message"  : "Nothing on the site links to this page, though the sitemap advertises it. A visitor cannot reach it by clicking.",
					"detail"   : "Add it to a menu, or link it from a related page."
				} );
			}

			if ( !page.seeded && isLinked ) {
				found.append( {
					"path"     : page.path,
					"checkId"  : "sitemap.missing",
					"severity" : "notice",
					"message"  : "This page is linked from the site but is not in the sitemap. That may be deliberate.",
					"detail"   : "A page is left out when ""Include in sitemap"" is off, or when it is marked noindex."
				} );
			}
		}

		return found;
	}

}
