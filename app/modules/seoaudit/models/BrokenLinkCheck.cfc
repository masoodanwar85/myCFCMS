/**
 * Internal links that go nowhere, or go somewhere via a detour.
 *
 * Reported against the page **containing** the link, because that is the page
 * somebody has to edit. A finding on the missing page would be useless — the
 * page does not exist, so there is nothing to open.
 *
 * ## Only internal links
 *
 * External links are never fetched. Checking them would mean an outbound HTTP
 * request per link to a third party, which is slow, makes the run depend on
 * other people's uptime, and reports a site as broken when someone else's
 * server is briefly down. If `example.com` is checked at all it should be
 * deliberately and on its own schedule, not as a side effect of auditing this
 * site's markup.
 *
 * ## Only links whose target the crawl actually reached
 *
 * A run is bounded by `maxUrls`, so a link may point at a page the crawl never
 * got to. That is unknown, not broken, and it is left alone — reporting it
 * would mean a bigger site produced hundreds of findings that say nothing more
 * than "the audit ran out of budget".
 */
component singleton accessors="true" {

	this.ID = "link";

	array function inspect( required array pages, required struct context ){
		var status = {};
		var found  = [];

		// What the crawl saw for each path it fetched.
		for ( var page in arguments.pages ) {
			status[ page.path ] = page.statusCode;
		}

		for ( var page in arguments.pages ) {
			// A page that did not render has no links worth judging, and its
			// own failure is already reported by StatusCheck.
			if ( page.statusCode != 200 ) {
				continue;
			}

			var broken    = [];
			var redirects = [];

			for ( var target in page.links ) {
				if ( !structKeyExists( status, target ) ) {
					continue;
				}

				var code = status[ target ];
				var shown = len( target ) ? "/" & target : "/";

				if ( code >= 400 || code == 0 ) {
					broken.append( shown & " (" & ( code ? code : "unreachable" ) & ")" );
				} else if ( code >= 300 && code < 400 ) {
					redirects.append( shown );
				}
			}

			if ( broken.len() ) {
				found.append( {
					"path"     : page.path,
					"checkId"  : "link.broken",
					"severity" : "error",
					"message"  : broken.len() == 1
						? "This page links to a URL that does not work."
						: "This page links to #broken.len()# URLs that do not work.",
					"detail"   : broken.toList( " | " )
				} );
			}

			if ( redirects.len() ) {
				found.append( {
					"path"     : page.path,
					"checkId"  : "link.redirect",
					"severity" : "notice",
					"message"  : "This page links through a redirect. Pointing straight at the destination saves a round trip.",
					"detail"   : redirects.toList( " | " )
				} );
			}
		}

		return found;
	}

}
