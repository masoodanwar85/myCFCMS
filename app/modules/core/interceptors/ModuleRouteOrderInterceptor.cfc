/**
 * Orders module entry-point routes most-specific-first.
 *
 * ColdBox prepends each module's entry point as it loads, so the routing table
 * ends up in reverse load order. That is fine until one module's entry point is
 * a prefix of another's — which is exactly the shape the admin uses:
 *
 *     admin           <- the admin shell
 *     admin/pages     <- contributed by the Pages module
 *     admin/blog      <- contributed by the Blog module
 *     admin/contact   <- contributed by the Contact module
 *
 * Whichever of those sits higher wins the URL. With ordering left to module
 * load order, `/admin/pages` and `/admin/blog` happened to work while
 * `/admin/contact` resolved to the admin shell and failed — the same code,
 * behaving differently for no reason a reader could see.
 *
 * A router should prefer the more specific pattern, so this makes it do that
 * once, after every module has registered.
 */
component extends="coldbox.system.Interceptor" {

	property name="router" inject="router@coldbox";

	/**
	 * Fires after all modules are loaded, which is the only point at which the
	 * full set of entry points is known.
	 */
	function afterAspectsLoad( event, interceptData ){
		var moduleRoutes = [];
		var appRoutes    = [];

		for ( var route in router.getRoutes() ) {
			if ( len( route.moduleRouting ?: "" ) ) {
				moduleRoutes.append( route );
			} else {
				appRoutes.append( route );
			}
		}

		if ( moduleRoutes.len() < 2 ) {
			return;
		}

		// Longest pattern first. For prefix routes, longer is more specific;
		// unrelated prefixes cannot shadow each other, so their order is
		// irrelevant.
		moduleRoutes.sort( ( a, b ) => len( b.pattern ?: "" ) - len( a.pattern ?: "" ) );

		// Module routes stay above the application's own, which end with the
		// public catch-all.
		moduleRoutes.append( appRoutes, true );

		router.setRoutes( moduleRoutes );

		log.info( "Ordered #moduleRoutes.len()# routes, module entry points most-specific-first." );
	}

}
