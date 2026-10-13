/**
 * Fetching one of the site's own pages, as a visitor would get it.
 *
 * ## Why HTTP at all, when the code is right here
 *
 * The alternative is to resolve and render in-process, which would be faster
 * and need no network. Two things make HTTP worth its cost:
 *
 *   - **The status code is a finding.** A URL that 404s or redirects is one of
 *     the most useful things an audit can report, and in-process rendering has
 *     no status code to report — only a returned string or an exception.
 *   - **It is the real path.** Going over HTTP exercises the router, the tenant
 *     interceptor, the resolver registry, the theme and the layout exactly as
 *     a visitor does. An in-process shortcut would be a second rendering path
 *     that can drift from the first, and an audit of a path nobody browses is
 *     an audit of the wrong thing.
 *
 * ## Why loopback, and why the Host header
 *
 * A site is identified by its `Host` header — that is how `TenantResolver`
 * works. So the request goes to the loopback address on the port serving the
 * current request, carrying the site's own primary domain as `Host`. That
 * reaches the right site without depending on the domain actually resolving in
 * DNS, which it does not on a developer's machine.
 *
 * `fetchBaseUrl` overrides the derived address for a deployment where the
 * server cannot reach itself that way — TLS terminated elsewhere, or a
 * container that does not listen on the port it is advertised on.
 *
 * ## No session, deliberately
 *
 * `cfhttp` carries no cookies from the admin request that started the run, so
 * every page is fetched as an anonymous visitor. That is the point: an audit
 * should see what the public sees, not a draft visible to the person running it.
 */
component singleton accessors="true" {

	property name="settings" inject="coldbox:moduleSettings:seoaudit";
	property name="domains"  inject="SiteDomainRepository@core";
	property name="log"      inject="logbox:logger:{this}";

	/**
	 * Fetch one path for one site.
	 *
	 * Never throws. A fetch that fails is a finding, so the failure is returned
	 * as data and the run carries on to the next URL.
	 *
	 * @baseUrl Where to fetch from. Passed in rather than derived, because a
	 *          run happens on a background thread and `cgi` is not populated
	 *          there — the port has to be read on the request thread that
	 *          started the run and carried across. Empty means derive it,
	 *          which is only correct on a request thread.
	 *
	 * @return { statusCode, body, location, error, elapsedMs }
	 */
	struct function fetch( required numeric siteId, required string path, string baseUrl = "" ){
		var host = hostFor( arguments.siteId );
		var base = len( trim( arguments.baseUrl ) )
			? reReplace( trim( arguments.baseUrl ), "/+$", "" )
			: resolveBaseUrl();

		var result = {
			"statusCode" : 0,
			"body"       : "",
			"location"   : "",
			"error"      : "",
			"elapsedMs"  : 0
		};

		if ( !len( host ) ) {
			result.error = "The site has no active domain, so there is no Host header to fetch with.";
			return result;
		}

		var url      = base & "/" & reReplace( arguments.path, "^/+", "", "one" );
		var started  = getTickCount();
		var response = "";

		try {
			cfhttp(
				url            = url,
				method         = "GET",
				timeout        = val( settings.timeout ?: 15 ),
				throwOnError   = false,
				redirect       = false,
				userAgent      = "myCFCMS-SEO-Audit",
				result         = "response"
			) {
				// What makes the right tenant answer.
				cfhttpparam( type = "header", name = "Host", value = host );
				// Asks the front controller not to hand back a cached page, so
				// the audit reports what the site renders now.
				cfhttpparam( type = "header", name = "Cache-Control", value = "no-cache" );
			}
		} catch ( any e ) {
			result.error     = e.message;
			result.elapsedMs = getTickCount() - started;

			log.warn( "SEO audit could not fetch [#url#]: #e.message#" );

			return result;
		}

		result.elapsedMs = getTickCount() - started;

		// `cfhttp` reports a connection failure in `statusCode` as text rather
		// than a number ("Connection Failure"), so the code is parsed out
		// instead of trusted.
		//
		// `reFind` with `returnSubExpressions` hands back `len` and `pos` as
		// *arrays*, not numbers — using `code.len` as a boolean throws "cannot
		// convert ArrayList to a boolean" and took the whole run down.
		var status = trim( response.statusCode ?: "" );
		var code   = reFind( "^\d{3}", status, 1, true );

		result.statusCode = arrayLen( code.len ) && code.len[ 1 ]
			? val( mid( status, code.pos[ 1 ], code.len[ 1 ] ) )
			: 0;

		if ( !result.statusCode ) {
			result.error = trim( response.errorDetail ?: response.statusCode ?: "No response" );
			return result;
		}

		result.body     = response.fileContent ?: "";
		result.location = trim( response.responseHeader[ "Location" ] ?: "" );

		return result;
	}

	/**
	 * The absolute URL a visitor would use for this path — what a canonical tag
	 * is compared against. Built from the site's primary domain rather than
	 * from the loopback address the fetch actually used, because the loopback
	 * address is an implementation detail and no canonical should ever name it.
	 */
	string function publicUrl( required numeric siteId, required string path ){
		var primary = domains.findPrimaryForSite( arguments.siteId );

		if ( isNull( primary ) ) {
			return "";
		}

		var clean = reReplace( arguments.path, "^/+|/+$", "", "all" );

		return "https://" & primary.getDomain() & ( len( clean ) ? "/" & clean : "/" );
	}

	/* --------------------------------------------------------------- internals */

	/**
	 * The primary domain, or any active one.
	 *
	 * A site with no primary domain still has pages worth auditing, so this
	 * falls back rather than refusing. That the primary is missing is itself
	 * reported, once, by the run.
	 */
	private string function hostFor( required numeric siteId ){
		var primary = domains.findPrimaryForSite( arguments.siteId );

		if ( !isNull( primary ) ) {
			return primary.getDomain();
		}

		var all = domains.findBySiteId( arguments.siteId );

		for ( var domain in all ) {
			if ( domain.getIsActive() ) {
				return domain.getDomain();
			}
		}

		return "";
	}

	/**
	 * Where a run should fetch from.
	 *
	 * **Call this on a request thread.** It reads `cgi.server_port` to find the
	 * port this installation is actually served on, and `cgi` is empty inside a
	 * `cfthread` — a run that derived its own base URL in the background would
	 * quietly fetch `http://127.0.0.1` on port 80 and report that every page on
	 * the site is unreachable.
	 *
	 * Public for that reason: the service resolves it before spawning the
	 * thread and passes it to every `fetch`.
	 */
	string function resolveBaseUrl(){
		var override = trim( settings.fetchBaseUrl ?: "" );

		if ( len( override ) ) {
			return reReplace( override, "/+$", "" );
		}

		// The port this request arrived on, so a developer's random CommandBox
		// port needs no configuration.
		var port = val( cgi.server_port ?: 0 );

		return "http://127.0.0.1" & ( port && port != 80 ? ":" & port : "" );
	}

}
