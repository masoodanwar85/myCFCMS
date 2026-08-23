/**
 * The single answer to "which site is this request for?".
 *
 * Everything above the resolver — handlers, services, views, and later the REST
 * and GraphQL layers — asks this object instead of inspecting the host itself.
 * That is the whole point: domain parsing happens once, in one place, and no
 * feature module ever grows its own copy of it.
 *
 * A singleton that keeps its state in the `request` scope, rather than a
 * request-scoped WireBox object. The distinction matters: a request-scoped
 * object injected into a singleton service would be captured at creation and
 * go stale on the next request (scope-widening injection). Because the state
 * lives in `request`, this object can be injected anywhere, in any scope,
 * and always reports the current request's tenant.
 */
component singleton {

	variables.REQUEST_KEY = "cms_currentSite";

	/**
	 * Record the resolved site for this request. Called by TenantInterceptor.
	 */
	function setCurrentTenant( required core.models.tenancy.Site site ){
		request[ variables.REQUEST_KEY ] = arguments.site;
		return this;
	}

	/**
	 * The current site.
	 *
	 * @throws Tenancy.NoCurrentTenant when the request could not be attributed
	 *         to a site. Callers that can cope with that should use
	 *         `hasCurrentTenant()` or `getCurrentTenantOrNull()` instead.
	 */
	core.models.tenancy.Site function getCurrentTenant(){
		if ( !hasCurrentTenant() ) {
			throw(
				type    = "Tenancy.NoCurrentTenant",
				message = "No tenant has been resolved for the current request.",
				detail  = "The request host did not match an active domain of an active site."
			);
		}

		return request[ variables.REQUEST_KEY ];
	}

	/**
	 * @return The current Site, or null when the request has no tenant.
	 */
	function getCurrentTenantOrNull(){
		if ( !hasCurrentTenant() ) {
			return;
		}

		return request[ variables.REQUEST_KEY ];
	}

	boolean function hasCurrentTenant(){
		return structKeyExists( request, variables.REQUEST_KEY )
			&& !isNull( request[ variables.REQUEST_KEY ] );
	}

	/**
	 * Convenience for the value that scopes almost every tenant-owned query.
	 */
	numeric function getCurrentTenantId(){
		return getCurrentTenant().getId();
	}

	/**
	 * Drop the tenant for this request.
	 *
	 * Called at the start of every request so a pooled thread can never inherit
	 * the previous request's tenant, and used by tests to reset between cases.
	 */
	function clear(){
		structDelete( request, variables.REQUEST_KEY );
		return this;
	}

}
