/**
 * Establishes the tenant for every request, once, before any handler runs.
 *
 *   Request → resolve domain → find site → TenantContext → execute request
 *
 * This is the only place tenant resolution is triggered. Handlers never look at
 * the host, and no feature module needs to know how a tenant is identified.
 *
 * An unresolved domain is not an error here. Group 1 has no routing or theming
 * policy yet, so the request continues with an empty context and announces
 * `onTenantNotResolved`; deciding what an unknown host should see (a 404, a
 * landing page, a redirect) belongs with routing in a later group.
 */
component extends="coldbox.system.Interceptor" {

	property name="tenantResolver" inject="TenantResolver@core";
	property name="tenantContext"  inject="TenantContext@core";

	function configure(){
	}

	/**
	 * Runs before the executing event, so `prc.currentSite` and TenantContext
	 * are already populated by the time any handler or view is reached.
	 */
	function preProcess( event, interceptData, rc, prc ){
		// Threads are pooled and `request` is not guaranteed clean; never let a
		// previous request's tenant leak into this one.
		tenantContext.clear();

		var site = tenantResolver.resolveFromEvent( arguments.event );

		if ( isNull( site ) ) {
			announce( "onTenantNotResolved", { domain : tenantResolver.getRequestDomain( arguments.event ) } );
			return;
		}

		tenantContext.setCurrentTenant( site );

		// Convenience for views and handlers; TenantContext stays the source of truth.
		arguments.prc.currentSite = site;

		announce( "onTenantResolved", { site : site } );
	}

}
