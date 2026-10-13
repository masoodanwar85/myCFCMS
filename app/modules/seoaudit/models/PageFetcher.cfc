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
 * ## How the address is chosen
 *
 * **Through the hostname this request already arrived on**, whenever that
 * hostname is one of the site's own. It is reachable by proof — the admin
 * request got here through it — the scheme is known for the same reason, and
 * no `Host` header has to be overridden.
 *
 * The first version derived `http://127.0.0.1:<cgi.server_port>` and overrode
 * `Host`. That works on a developer's machine and fails completely on a TLS
 * site: `cgi.server_port` is 443, so the fetch is plain HTTP against an
 * SSL-enabled port, and Apache answers **400 Bad Request** to every URL. A
 * report of 173 identical errors is what that looks like from the outside.
 *
 * Loopback with a `Host` override stays as the fallback, for the case the
 * first version was really written for: a developer's machine, where the
 * site's domain (`something.test`) does not resolve in DNS and the admin is
 * reached on `127.0.0.1` instead. ColdFusion's `cfhttp` replaces the `Host`
 * header rather than adding a second — verified on the wire — so the override
 * is safe where it is needed.
 *
 * `fetchBaseUrl` overrides everything, for a deployment that can reach itself
 * at neither address.
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
	 * Where a run should fetch from, and whether it must override `Host`.
	 *
	 * **Call this on a request thread.** It reads `cgi`, which is empty inside
	 * a `cfthread` — a run that resolved its own address in the background
	 * would fall through to a guess and report every page on the site as
	 * unreachable. The service resolves it before spawning the thread and
	 * passes it to every `fetch`.
	 *
	 * @return { baseUrl, hostHeader } — `hostHeader` empty when none is needed.
	 */
	struct function resolveTarget( required numeric siteId ){
		var override = trim( settings.fetchBaseUrl ?: "" );

		if ( len( override ) ) {
			return {
				"baseUrl"    : reReplace( override, "/+$", "" ),
				// An explicit address may well be loopback, so the site still
				// has to be named. Harmless when it is already the right host.
				"hostHeader" : hostFor( arguments.siteId )
			};
		}

		var requestHost = lCase( trim( cgi.http_host ?: "" ) );

		// The hostname this very request arrived on, when it belongs to the
		// site being audited. Reachable by proof, with a scheme that is known
		// rather than guessed, and no header to override.
		if ( len( requestHost ) && isSiteHost( arguments.siteId, requestHost ) ) {
			return {
				"baseUrl"    : requestScheme() & "://" & requestHost,
				"hostHeader" : ""
			};
		}

		// A developer's machine: the admin is on `127.0.0.1` and the site's
		// own domain does not resolve. Loopback, naming the site explicitly.
		var host = hostFor( arguments.siteId );

		if ( !len( host ) ) {
			return { "baseUrl" : "", "hostHeader" : "" };
		}

		var port = val( cgi.server_port ?: 0 );

		return {
			"baseUrl"    : "http://127.0.0.1" & ( port && port != 80 ? ":" & port : "" ),
			"hostHeader" : host
		};
	}

	/**
	 * Fetch one path for one site.
	 *
	 * Never throws. A fetch that fails is a finding, so the failure is returned
	 * as data and the run carries on to the next URL.
	 *
	 * @baseUrl    Resolved by `resolveTarget` on the request thread and carried
	 *             across, because `cgi` is empty in the background thread that
	 *             does the work.
	 * @hostHeader The `Host` to send, when the address is not the site's own.
	 *
	 * @return { statusCode, body, location, error, elapsedMs }
	 */
	struct function fetch(
		required numeric siteId,
		required string path,
		string baseUrl    = "",
		string hostHeader = ""
	){
		var target = len( trim( arguments.baseUrl ) )
			? {
				"baseUrl"    : reReplace( trim( arguments.baseUrl ), "/+$", "" ),
				"hostHeader" : trim( arguments.hostHeader )
			}
			: resolveTarget( arguments.siteId );

		var base = target.baseUrl;
		var host = target.hostHeader;

		var result = {
			"statusCode" : 0,
			"body"       : "",
			"location"   : "",
			"error"      : "",
			"elapsedMs"  : 0
		};

		if ( !len( base ) ) {
			result.error = "This site has no domain the server can fetch it through. Set the SEO audit's fetchBaseUrl.";
			return result;
		}

		var url      = base & "/" & reReplace( arguments.path, "^/+", "", "one" );
		var started  = getTickCount();
		var response = "";

		try {
			cfhttp(
				url          = url,
				method       = "GET",
				timeout      = val( settings.timeout ?: 15 ),
				throwOnError = false,
				redirect     = false,
				userAgent    = "myCFCMS-SEO-Audit",
				result       = "response"
			) {
				// Only when fetching through an address that is not the site's
				// own hostname — over loopback, that is what makes the right
				// tenant answer. Left out where it is not needed, so the
				// request is identical to one a visitor would make.
				if ( len( host ) ) {
					cfhttpparam( type = "header", name = "Host", value = host );
				}

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
	 * from whatever address the fetch actually used, because that address is an
	 * implementation detail and no canonical should ever name it.
	 *
	 * The scheme here does not matter: `CanonicalCheck` compares host and path
	 * and ignores it, precisely because the audit may fetch over a different
	 * scheme than the site is published on.
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
	 * `https` when this request came over TLS.
	 *
	 * Behind Apache or nginx the connector normally forwards it, so all three
	 * signals are checked rather than trusting one — getting this wrong means
	 * fetching plain HTTP against a TLS port, which is the whole reason this
	 * function exists.
	 */
	private string function requestScheme(){
		if ( lCase( cgi.https ?: "" ) == "on" ) {
			return "https";
		}

		if ( val( cgi.server_port_secure ?: 0 ) == 1 ) {
			return "https";
		}

		if ( val( cgi.server_port ?: 0 ) == 443 ) {
			return "https";
		}

		return "http";
	}

	private boolean function isSiteHost( required numeric siteId, required string host ){
		// Without the port: a domain is registered as a hostname, and a
		// developer's `example.test:8080` is still `example.test`.
		var bare = listFirst( arguments.host, ":" );

		for ( var domain in domains.findBySiteId( arguments.siteId ) ) {
			if ( domain.getIsActive() && lCase( domain.getDomain() ) == bare ) {
				return true;
			}
		}

		return false;
	}

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

		for ( var domain in domains.findBySiteId( arguments.siteId ) ) {
			if ( domain.getIsActive() ) {
				return domain.getDomain();
			}
		}

		return "";
	}

}
