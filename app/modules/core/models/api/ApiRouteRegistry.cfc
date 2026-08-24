/**
 * The resources the API serves, declared by the modules that own them.
 *
 * A module cannot simply add `/api/v1/pages` to its own `routes` array: module
 * routes are relative to the module's entry point, and Pages lives at
 * `admin/pages`. Nor can it push a route onto the application router in
 * `onLoad`, because that appends *below* the public catch-all, where nothing
 * will ever reach it.
 *
 * So a module declares a **resource** and Core builds the routes:
 *
 *     wirebox.getInstance( "ApiRouteRegistry@core" )
 *            .resource( name = "pages", module = "pages", handler = "Api" );
 *
 * which produces the conventional set:
 *
 *     GET    /api/v1/pages              -> index
 *     POST   /api/v1/pages              -> create
 *     GET    /api/v1/pages/:id          -> show
 *     PATCH  /api/v1/pages/:id          -> update
 *     PUT    /api/v1/pages/:id          -> update
 *     DELETE /api/v1/pages/:id          -> remove
 *
 * A module may name extra **member actions** for the things REST has no verb
 * for, and they become `POST /api/v1/pages/:id/<action>`:
 *
 *     .resource( name = "pages", module = "pages", memberActions = "publish,unpublish" )
 *
 * Named explicitly rather than routed from a `:action` placeholder in the URL.
 * A placeholder would let a caller name *any* public method on the handler and
 * have the framework invoke it — including inherited ones — which turns a
 * routing convenience into a way to reach code nobody meant to expose.
 *
 * The conventions are Core's so that two modules cannot disagree about what a
 * collection URL looks like, which is the sort of inconsistency an API is
 * judged on and can never fix afterwards.
 */
component singleton accessors="true" {

	property name="log" inject="logbox:logger:{this}";

	this.PREFIX = "/api/v1";

	function init(){
		variables.resources = [];
		return this;
	}

	/**
	 * @name    The collection segment, e.g. `pages`.
	 * @module  The owning module.
	 * @handler The handler within it.
	 * @only    Optionally restrict which actions are exposed, e.g. "index,show"
	 *          for a read-only resource.
	 */
	function resource(
		required string name,
		required string module,
		string handler       = "Api",
		string only          = "",
		string memberActions = ""
	){
		var segment = lCase( trim( arguments.name ) );

		for ( var existing in variables.resources ) {
			if ( existing.name == segment ) {
				throw(
					type    = "Api.ResourceAlreadyRegistered",
					message = "[#segment#] is already served by the [#existing.module#] module."
				);
			}
		}

		variables.resources.append( {
			"name"          : segment,
			"module"        : arguments.module,
			"handler"       : arguments.handler,
			"only"          : arguments.only,
			"memberActions" : arguments.memberActions
		} );

		return this;
	}

	function unregister( required string name ){
		var segment = lCase( trim( arguments.name ) );

		variables.resources = variables.resources.filter( ( r ) => r.name != segment );

		return this;
	}

	array function getResources(){
		return variables.resources;
	}

	/**
	 * The route definitions to hand the router, most specific first.
	 *
	 * Returned as data rather than registered here, so the thing that knows
	 * *when* it is safe to touch the routing table stays in one place.
	 */
	/**
	 * The route definitions to hand the router, most specific first.
	 *
	 * **One entry per pattern**, carrying a verb-to-action map. ColdBox merges
	 * routes that share a pattern, so registering `/pages/:id` once for GET and
	 * again for DELETE does not produce two routes — it produces one with both
	 * verbs and no action at all, which matches every request and dispatches
	 * none of them.
	 *
	 * Returned as data rather than registered here, so the thing that knows
	 * *when* it is safe to touch the routing table stays in one place.
	 */
	array function buildRoutes(){
		var routes = [];

		for ( var res in variables.resources ) {
			var base = this.PREFIX & "/" & res.name;

			// Member actions first. A member route must be declared above
			// `/:id`, or `/pages/12/publish` is read as a page whose id is
			// "12/publish".
			for ( var member in listToArray( res.memberActions ) ) {
				var name = trim( member );

				routes.append( {
					pattern : base & "/" & ":id/" & name,
					module  : res.module,
					handler : res.handler,
					actions : { "POST" : name }
				} );
			}

			var member = {
				"GET"    : "show",
				"PATCH"  : "update",
				"PUT"    : "update",
				"DELETE" : "remove"
			};

			var collection = {
				"GET"  : "index",
				"POST" : "create"
			};

			var memberActions     = allowed( member, res.only );
			var collectionActions = allowed( collection, res.only );

			if ( !memberActions.isEmpty() ) {
				routes.append( {
					pattern : base & "/:id",
					module  : res.module,
					handler : res.handler,
					actions : memberActions
				} );
			}

			if ( !collectionActions.isEmpty() ) {
				routes.append( {
					pattern : base,
					module  : res.module,
					handler : res.handler,
					actions : collectionActions
				} );
			}
		}

		return routes;
	}

	/**
	 * Drop the verbs a resource did not ask for, so `only = "index,show"`
	 * produces a genuinely read-only resource rather than one that merely does
	 * not advertise its writes.
	 */
	private struct function allowed( required struct map, string only = "" ){
		if ( !len( trim( arguments.only ) ) ) {
			return arguments.map;
		}

		var kept = {};

		for ( var verb in arguments.map ) {
			if ( listFindNoCase( arguments.only, arguments.map[ verb ] ) ) {
				kept[ verb ] = arguments.map[ verb ];
			}
		}

		return kept;
	}

}
