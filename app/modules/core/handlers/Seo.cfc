/**
 * The two files a crawler asks for before it reads anything else.
 *
 * Both are **per tenant**, which is the whole reason they are handlers rather
 * than static files in the webroot. A static `/robots.txt` would be one file
 * shared by every site on the installation, so a staging tenant could not be
 * closed to crawlers without closing every client's site with it.
 *
 * Neither needs authentication, and neither reveals anything a reader could not
 * find by following links — a sitemap lists published content only, which is by
 * definition public.
 */
component extends="coldbox.system.EventHandler" {

	property name="tenantContext" inject="TenantContext@core";
	property name="seo"           inject="SeoService@core";
	property name="sitemap"       inject="SitemapRegistry@core";

	/**
	 * `/sitemap.xml`
	 *
	 * Built by hand rather than through a view, because whitespace before the
	 * XML declaration makes the document invalid and a CFML view is mostly
	 * whitespace. `event.renderData` sets the content type and skips the layout.
	 */
	function sitemap( event, rc, prc ){
		if ( !tenantContext.hasCurrentTenant() ) {
			return notFound( event );
		}

		var site   = tenantContext.getCurrentTenant();
		var siteId = site.getId();

		// A site that is closed to crawlers should not hand one a list of
		// everything it has. robots.txt already says no; this makes the refusal
		// hold even for a crawler that skipped it.
		if ( !seo.isIndexable( siteId ) ) {
			return notFound( event );
		}

		var xml = [ '<?xml version="1.0" encoding="UTF-8"?>' ];

		xml.append( '<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">' );

		for ( var entry in sitemap.getEntriesFor( siteId ) ) {
			var location = seo.absoluteUrl( siteId, entry.path );

			// No primary domain means no absolute URL, and a sitemap entry
			// without one is invalid. Skip rather than emit a broken document.
			if ( !len( location ) ) {
				continue;
			}

			var node = "	<url>" & chr( 10 ) & "		<loc>" & xmlFormat( location ) & "</loc>";

			if ( isDate( entry.lastModified ) ) {
				// W3C datetime, which is what the sitemap protocol asks for.
				node &= chr( 10 ) & "		<lastmod>" & dateTimeFormat( entry.lastModified, "yyyy-mm-dd" ) & "</lastmod>";
			}

			if ( len( entry.changeFrequency ) ) {
				node &= chr( 10 ) & "		<changefreq>" & entry.changeFrequency & "</changefreq>";
			}

			node &= chr( 10 ) & "		<priority>" & numberFormat( entry.priority, "0.0" ) & "</priority>";
			node &= chr( 10 ) & "	</url>";

			xml.append( node );
		}

		xml.append( "</urlset>" );

		event.renderData(
			type        = "plain",
			data        = xml.toList( chr( 10 ) ),
			contentType = "application/xml",
			statusCode  = 200
		);
	}

	/**
	 * `/robots.txt`
	 *
	 * Points at the site's own sitemap, so a crawler that finds the file has
	 * everything it needs without guessing.
	 */
	function robots( event, rc, prc ){
		if ( !tenantContext.hasCurrentTenant() ) {
			return notFound( event );
		}

		var site   = tenantContext.getCurrentTenant();
		var siteId = site.getId();
		var lines  = [ "User-agent: *" ];

		if ( seo.isIndexable( siteId ) ) {
			lines.append( "Disallow:" );

			// The admin is not secret — it refuses anyone without a session —
			// but there is nothing in it for a crawler, and every request it
			// makes there is one it does not spend on the site's content.
			lines.append( "Disallow: /admin" );

			var sitemapUrl = seo.absoluteUrl( siteId, "sitemap.xml" );

			if ( len( sitemapUrl ) ) {
				lines.append( "" );
				lines.append( "Sitemap: " & sitemapUrl );
			}
		} else {
			lines.append( "Disallow: /" );
		}

		event.renderData(
			type        = "plain",
			data        = lines.toList( chr( 10 ) ) & chr( 10 ),
			contentType = "text/plain",
			statusCode  = 200
		);
	}

	/**
	 * An unknown host asks for these too. Answer the same way the front
	 * controller does — nothing here belongs to any site.
	 */
	private function notFound( event ){
		event.renderData(
			type        = "plain",
			data        = "",
			contentType = "text/plain",
			statusCode  = 404
		);
	}

}
