/**
 * Which URLs a run should look at.
 *
 * ## Two sources, because neither is complete
 *
 * **The sitemap** is what the site *claims* it publishes. `SitemapRegistry`
 * already collects it from every module that registers a provider, which is
 * the right seam — but today only Pages and Blog register one. So `/faq`,
 * `/contact` and the other module landing pages are absent from it, and a run
 * seeded only from the sitemap would report a confident page count while never
 * looking at them.
 *
 * **Internal links** fill that gap. Every page fetched is parsed anyway, so its
 * links cost nothing extra, and following them reaches `/faq` because the theme
 * links it from the navigation. It also means the audit covers exactly what a
 * crawler would reach, which is the thing being audited.
 *
 * The crawl is bounded by `maxUrls`, so this is a budget rather than an
 * exhaustive walk. Seeded URLs are queued first, so the sitemap's content is
 * always audited before the budget goes on discovered extras.
 *
 * ## What is deliberately not followed
 *
 * Anything that is not an HTML page of this site. Served files (`/media/...`),
 * the admin, other hosts, `mailto:`, and anything with a file extension that
 * is not a page. Fetching a 20MB PDF to check its `<title>` is a waste of a
 * run's budget, and auditing another site's pages is not this module's
 * business.
 */
component singleton accessors="true" {

	property name="sitemap"  inject="SitemapRegistry@core";
	property name="targets"  inject="LinkTargetRegistry@core";
	property name="domains"  inject="SiteDomainRepository@core";
	property name="log"      inject="logbox:logger:{this}";

	// Extensions that are not pages. Checked against the end of the path.
	variables.NOT_PAGES = "pdf,jpg,jpeg,png,gif,webp,svg,ico,css,js,json,xml,rss,atom,txt,csv,zip,doc,docx,xls,xlsx,ppt,pptx,mp4,mp3,woff,woff2,ttf,eot,webmanifest,map";

	// Path prefixes that are never public content.
	variables.SKIP_PREFIXES = [ "admin", "media" ];

	/**
	 * The paths a run starts from: everything the site's sitemap advertises,
	 * plus the home page, which is always worth auditing and is not guaranteed
	 * to be listed.
	 */
	array function seedFor( required numeric siteId ){
		var seen  = { "" : true };
		var paths = [ "" ];

		try {
			for ( var entry in sitemap.getEntriesFor( arguments.siteId ) ) {
				var path = normalisePath( entry.path ?: "" );

				if ( !structKeyExists( seen, path ) ) {
					seen[ path ] = true;
					paths.append( path );
				}
			}
		} catch ( any e ) {
			// A run over the home page alone is worth more than no run.
			log.warn( "SEO audit could not read the sitemap for site [#arguments.siteId#]: #e.message#" );
		}

		return paths;
	}

	/**
	 * Path -> the page behind it, for the "edit this page" link in the report.
	 *
	 * Built from `LinkTargetRegistry`, which every module that owns addressable
	 * content already feeds for the menu editor. Using it here means this
	 * module needs no dependency on Pages or Blog — and a module that teaches
	 * the menu editor about its content teaches this at the same time.
	 */
	struct function pageIndexFor( required numeric siteId ){
		var index = {};

		try {
			for ( var target in targets.getLinkTargets( arguments.siteId ) ) {
				var path = normalisePath( target.path ?: "" );

				// First wins. Two things claiming one path is a routing bug
				// elsewhere, not something to resolve here.
				if ( !structKeyExists( index, path ) ) {
					index[ path ] = {
						"type"  : target.type ?: "",
						"id"    : val( target.id ?: 0 ),
						"label" : target.label ?: ""
					};
				}
			}
		} catch ( any e ) {
			log.warn( "SEO audit could not index link targets for site [#arguments.siteId#]: #e.message#" );
		}

		return index;
	}

	/**
	 * A link found on a page, turned into a path this run could audit — or
	 * **null** if it is not one.
	 *
	 * Null rather than an empty string, because an empty string is a real
	 * answer: it is the home page. Using `""` for both would make a link to
	 * `mailto:` indistinguishable from a link to `/`, and the caller would
	 * either skip the home page or queue every email address on the site.
	 *
	 * @href        The raw `href` as written in the page.
	 * @siteDomains The hostnames this site answers on, lowercase.
	 */
	function pathFromLink( required string href, required array siteDomains ){
		var link = trim( arguments.href );

		if ( !len( link ) ) {
			return;
		}

		// Fragment-only and non-HTTP schemes.
		if ( left( link, 1 ) == "##" ) {
			return;
		}

		if ( reFindNoCase( "^(mailto|tel|javascript|data|ftp|sms):", link ) ) {
			return;
		}

		// Protocol-relative, treated as absolute.
		if ( left( link, 2 ) == "//" ) {
			link = "https:" & link;
		}

		if ( reFindNoCase( "^https?://", link ) ) {
			var host = lCase( reReplaceNoCase( link, "^https?://([^/:?##]+).*$", "\1" ) );

			// Another site's page is not this site's problem.
			if ( !arguments.siteDomains.findNoCase( host ) ) {
				return;
			}

			link = reReplaceNoCase( link, "^https?://[^/]+", "", "one" );
		} else if ( left( link, 1 ) != "/" ) {
			// A relative link. Resolving it needs the page it was found on, and
			// this CMS emits absolute paths everywhere, so rather than guess
			// wrongly it is skipped — and said out loud in the log, because a
			// theme that starts emitting them should be noticed.
			log.debug( "SEO audit skipped a relative link it cannot resolve: [#arguments.href#]" );
			return;
		}

		// Fragments and query strings name the same document.
		// `"##"` is one literal hash: `"###"` would leave an unterminated
		// interpolation and fail to compile.
		link = listFirst( link, "##" );
		link = listFirst( link, "?" );

		var path = normalisePath( link );

		if ( !isAuditable( path ) ) {
			return;
		}

		return path;
	}

	/**
	 * The hostnames a site answers on, for telling an internal link from an
	 * external one.
	 */
	array function domainsFor( required numeric siteId ){
		var hosts = [];

		for ( var domain in domains.findBySiteId( arguments.siteId ) ) {
			hosts.append( lCase( domain.getDomain() ) );
		}

		return hosts;
	}

	/**
	 * Whether a path is an HTML page of this site worth fetching.
	 *
	 * The home page — an empty path — is auditable; everything else is judged
	 * on its prefix and extension.
	 */
	boolean function isAuditable( required string path ){
		var clean = normalisePath( arguments.path );

		if ( !len( clean ) ) {
			return true;
		}

		var firstSegment = lCase( listFirst( clean, "/" ) );

		for ( var prefix in variables.SKIP_PREFIXES ) {
			if ( firstSegment == prefix ) {
				return false;
			}
		}

		// `listLast` on a path with no dot returns the whole segment, so the
		// extension is only taken when there actually is one.
		var lastSegment = listLast( clean, "/" );

		if ( find( ".", lastSegment ) ) {
			var extension = lCase( listLast( lastSegment, "." ) );

			if ( listFindNoCase( variables.NOT_PAGES, extension ) ) {
				return false;
			}
		}

		return true;
	}

	string function normalisePath( required string path ){
		return reReplace( trim( arguments.path ), "^/+|/+$", "", "all" );
	}

}
