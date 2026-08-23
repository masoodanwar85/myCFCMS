/**
 * Maps an incoming hostname onto a Site.
 *
 * Resolution is pure lookup: no request state, no side effects, no writing to
 * the context. TenantInterceptor decides what to do with the answer, which
 * keeps this object usable from a CLI task or a test with a bare string.
 */
component singleton accessors="true" {

	property name="siteRepository"   inject="SiteRepository@core";
	property name="domainNormalizer" inject="DomainNormalizer@core";
	property name="settings"         inject="coldbox:moduleSettings:core";

	/**
	 * @domain Any hostname; it is normalised before lookup.
	 *
	 * @return The active Site owning that domain, or null when the domain is
	 *         unknown, inactive, ignored, or belongs to an inactive site.
	 */
	function resolveByDomain( string domain = "" ){
		var host = domainNormalizer.normalize( arguments.domain );

		if ( !len( host ) || isIgnored( host ) ) {
			return;
		}

		return siteRepository.findActiveByDomain( host );
	}

	/**
	 * Resolve the tenant for a live ColdBox request.
	 */
	function resolveFromEvent( required any event ){
		return resolveByDomain( getRequestDomain( arguments.event ) );
	}

	/**
	 * The normalised hostname this request arrived on.
	 *
	 * Prefers the `Host` header and falls back to CGI, so the value is the same
	 * whether the request came through a proxy, the built-in server, or a test.
	 */
	string function getRequestDomain( required any event ){
		var host = arguments.event.getHTTPHeader( "Host", "" );

		if ( !len( host ) ) {
			host = cgi.http_host ?: "";
		}

		if ( !len( host ) ) {
			host = cgi.server_name ?: "";
		}

		return domainNormalizer.normalize( host );
	}

	/**
	 * Hostnames configured as non-tenant (health checks, an admin hostname,
	 * and so on) never hit the database.
	 */
	boolean function isIgnored( required string host ){
		var ignored = structKeyExists( settings, "ignoredDomains" ) ? settings.ignoredDomains : [];

		for ( var candidate in ignored ) {
			if ( domainNormalizer.normalize( candidate ) == arguments.host ) {
				return true;
			}
		}

		return false;
	}

}
