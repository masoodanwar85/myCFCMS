/**
 * Puts the API's routes into the routing table, in the one window where that
 * is both possible and safe.
 *
 * Modules declare API resources in their own `onLoad`. By `afterAspectsLoad`
 * every module has been through that, so the full set is known — and the
 * routing table has just been reordered by ModuleRouteOrderInterceptor, which
 * is registered before this one so the two run in a defined order rather than
 * whichever ColdBox happens to reach first.
 *
 * API routes go **above** the application's own, because the last of those is
 * the public catch-all: a route added after it can never be reached, which is
 * exactly what happens if a module tries to register one itself.
 */
component extends="coldbox.system.Interceptor" {

	property name="router"   inject="router@coldbox";
	property name="registry" inject="ApiRouteRegistry@core";

	function afterAspectsLoad( event, interceptData ){
		var definitions = registry.buildRoutes();

		if ( !definitions.len() ) {
			return;
		}

		// Build the new routes through the router's own factory, then move them
		// to the front. Registering them directly would append below the
		// catch-all; constructing route structs by hand would couple this to
		// ColdBox's internal shape.
		var before = router.getRoutes().len();

		for ( var definition in definitions ) {
			// One `route()` call per verb, each naming a full
			// `module:Handler.action` event.
			//
			// Not `withModule()`: a route carrying a module is filed in that
			// module's own routing table and matched beneath its entry point —
			// which for Pages is `admin/pages`, so `/api/v1/pages` would never
			// reach it. The event form keeps the route in the application table
			// where the pattern is matched literally.
			//
			// ColdBox merges the repeated pattern into a single route with a
			// verb-to-event map, which is exactly the shape wanted.
			for ( var verb in definition.actions ) {
				router
					.route( definition.pattern )
					.withVerbs( verb )
					.to( definition.module & ":" & definition.handler & "." & definition.actions[ verb ] );
			}
		}

		var all   = router.getRoutes();
		var added = [];
		var rest  = [];

		for ( var i = 1; i <= all.len(); i++ ) {
			if ( i > before ) {
				added.append( all[ i ] );
			} else {
				rest.append( all[ i ] );
			}
		}

		added.append( rest, true );
		router.setRoutes( added );

		log.info( "Registered #added.len() - rest.len()# API routes above the public catch-all." );
	}

}
