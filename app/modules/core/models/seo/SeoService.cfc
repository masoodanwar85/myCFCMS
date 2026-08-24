/**
 * Everything the CMS needs to describe a page to a machine.
 *
 * Three jobs live here, and they all depend on one thing the rest of the
 * application never needed: an **absolute** URL. Every public URL elsewhere is
 * a path, because a path is what a browser needs and what a tenant-scoped
 * router understands. A canonical tag, an Open Graph tag and a sitemap entry
 * are all read by something that is not on the site, so each needs a scheme
 * and a host.
 *
 * Which host is a real question in a multi-tenant CMS. A site may answer on
 * several domains — `example.com`, `www.example.com`, a staging hostname — and
 * a canonical URL that changes depending on which one a reader happened to
 * arrive through is worse than no canonical URL at all. So the answer comes
 * from the site's **primary domain**, never from the request. That is what
 * makes a canonical tag do its job: reach the same page by four hostnames and
 * all four name one address.
 *
 * The scheme is the one thing taken from the request, because it is the one
 * thing the database cannot know: the same site is `http` behind a developer's
 * CommandBox and `https` in front of a load balancer. `seo.baseUrl` overrides
 * the lot when a deployment needs to state its address outright.
 */
component singleton accessors="true" {

	property name="domains"  inject="SiteDomainRepository@core";
	property name="settings" inject="SiteSettingsRepository@core";
	property name="log"      inject="logbox:logger:{this}";

	// Site settings this service reads. Kept as constants because the admin
	// screen writes the same keys, and a typo in either place would fail silently.
	this.KEY_BASE_URL    = "seo.baseUrl";
	this.KEY_INDEXABLE   = "seo.indexable";
	this.KEY_DESCRIPTION = "seo.defaultDescription";
	this.KEY_IMAGE       = "seo.defaultImage";

	/**
	 * The site's address, with no trailing slash: `https://example.com`.
	 *
	 * Returns an empty string when a site has no primary domain and no
	 * override. Callers must cope with that rather than emitting a canonical
	 * tag pointing at nothing — a wrong canonical de-indexes a site.
	 */
	string function baseUrl( required numeric siteId ){
		var override = trim( settings.getValue( arguments.siteId, this.KEY_BASE_URL, "" ) );

		if ( len( override ) ) {
			return reReplace( override, "/+$", "" );
		}

		var primary = domains.findPrimaryForSite( arguments.siteId );

		if ( isNull( primary ) ) {
			return "";
		}

		return requestScheme() & "://" & primary.getDomain();
	}

	/**
	 * A path turned into an absolute URL.
	 *
	 * A path that is already absolute is returned untouched, so a resolver that
	 * knows its own canonical address — or a media item on a CDN — is not
	 * mangled into nonsense like `https://example.com/https://cdn/...`.
	 */
	string function absoluteUrl( required numeric siteId, required string path ){
		var target = trim( arguments.path );

		if ( reFindNoCase( "^https?://", target ) ) {
			return target;
		}

		var base = baseUrl( arguments.siteId );

		if ( !len( base ) ) {
			return "";
		}

		return base & "/" & reReplace( target, "^/+", "" );
	}

	/**
	 * May search engines index this site at all?
	 *
	 * Defaults to **true**, because the common case is a real site that wants
	 * readers. A staging or holding site turns it off, which switches both the
	 * per-page robots tag and `/robots.txt` to a refusal — belt and braces,
	 * since a crawler may hold a URL it never re-fetches robots.txt for.
	 */
	boolean function isIndexable( required numeric siteId ){
		var stored = trim( settings.getValue( arguments.siteId, this.KEY_INDEXABLE, "" ) );

		if ( !len( stored ) ) {
			return true;
		}

		return isBoolean( stored ) && stored;
	}

	/**
	 * The metadata for one rendered page, ready for a theme to emit.
	 *
	 * Takes what the content resolver said about this URL and fills the gaps
	 * from the site's defaults, so a theme never has to decide what to do about
	 * a missing description.
	 *
	 * @path       The requested path, used when the resolver names no canonical.
	 * @resolution The normalised resolver result, or an empty struct for a 404.
	 */
	struct function metadataFor(
		required any site,
		required string path,
		struct resolution = {}
	){
		var siteId = arguments.site.getId();
		var r      = arguments.resolution;

		// `structKeyExists`, not `len()`. An empty canonical path is the site
		// root — a real answer, and the one the home page gives — so testing
		// for emptiness here would canonicalise `/home` to itself and hand a
		// search engine two URLs for one document.
		var canonicalPath = structKeyExists( r, "canonicalPath" ) ? r.canonicalPath : arguments.path;
		var description   = len( r.metaDescription ?: "" )
			? r.metaDescription
			: settings.getValue( siteId, this.KEY_DESCRIPTION, "" );

		var image = len( r.image ?: "" )
			? r.image
			: settings.getValue( siteId, this.KEY_IMAGE, "" );

		// A canonical tag on a 404 names a URL that does not exist as the
		// preferred address for a URL that does not exist. It is at best noise
		// and at worst an instruction to consolidate signals onto a dead page,
		// so an error response carries no canonical at all.
		var isSuccess = val( r.statusCode ?: 200 ) == 200;

		return {
			"canonical"   : isSuccess ? absoluteUrl( siteId, canonicalPath ) : "",
			"description" : description,
			"image"       : len( image ) ? absoluteUrl( siteId, image ) : "",
			"robots"      : robotsFor( siteId, r ),
			"type"        : len( r.contentType ?: "" ) ? r.contentType : "website",
			"siteName"    : arguments.site.getName(),
			"locale"      : arguments.site.getLocale(),
			"publishedAt" : r.publishedAt ?: "",
			"modifiedAt"  : r.modifiedAt ?: "",
			"keywords"    : r.keywords ?: "",
			// Fall back to the document title and description rather than
			// leaving a social card blank: a preview with no title is worse
			// than one repeating the page's own.
			"ogTitle"     : len( r.ogTitle ?: "" ) ? r.ogTitle : "",
			"ogDescription" : len( r.ogDescription ?: "" ) ? r.ogDescription : description,
			"twitterCard" : len( r.twitterCard ?: "" ) ? r.twitterCard : "",
			"headMarkup"  : r.headMarkup ?: "",
			"bodyMarkup"  : r.bodyMarkup ?: "",
			"jsonLd"      : r.jsonLd ?: ""
		};
	}

	/**
	 * The robots directive for one page.
	 *
	 * A site-wide `noindex` wins over anything a resolver asks for: turning a
	 * whole site off must not be quietly overridden page by page. A 404 is also
	 * always `noindex`, whatever it is rendering.
	 */
	string function robotsFor( required numeric siteId, struct resolution = {} ){
		if ( !isIndexable( arguments.siteId ) ) {
			return "noindex, nofollow";
		}

		if ( val( arguments.resolution.statusCode ?: 200 ) != 200 ) {
			return "noindex, follow";
		}

		return trim( arguments.resolution.robots ?: "" );
	}

	/**
	 * `http` or `https` for the request in flight.
	 *
	 * Checks the proxy header first: behind a load balancer that terminates TLS
	 * the connection to ColdFusion is plain HTTP, so `cgi.https` would report
	 * `off` for a site the reader reached over `https` — and every canonical
	 * tag on the site would point at the wrong scheme.
	 *
	 * Failing both, the answer is `http`, because that is what this request
	 * demonstrably is. A deployment that terminates TLS upstream must either
	 * pass `X-Forwarded-Proto` or set `seo.baseUrl` outright; both are in the
	 * deployment notes, and neither is guessed at here.
	 */
	private string function requestScheme(){
		var forwarded = lCase( trim( getHTTPRequestData( false ).headers[ "X-Forwarded-Proto" ] ?: "" ) );

		// A proxy chain sends a list: the client-facing scheme is the first.
		if ( len( forwarded ) ) {
			forwarded = trim( listFirst( forwarded ) );
		}

		if ( listFindNoCase( "http,https", forwarded ) ) {
			return forwarded;
		}

		return lCase( cgi.https ?: "off" ) == "on" ? "https" : "http";
	}

}
