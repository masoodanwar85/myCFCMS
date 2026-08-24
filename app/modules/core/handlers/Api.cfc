/**
 * The API's own two endpoints: what it is, and where a refusal lands.
 *
 * Everything else an API serves belongs to a module. Core owns the boundary,
 * the token, the error shape and the version prefix — the same division as the
 * public site, where Core owns routing and modules own content.
 */
component extends="core.models.api.ApiHandler" {

	property name="resolvers" inject="ContentResolverRegistry@core";

	// The root is deliberately reachable without a token: a client needs to be
	// able to ask what version it is talking to before it has credentials, and
	// nothing here is specific to a site's content.
	variables.publicActions = "index,refused";

	variables.permissions = { "$every" : "" };

	/**
	 * `GET /api/v1`
	 *
	 * A discovery document. Small on purpose — it says what this is and what
	 * authentication it expects, and does not enumerate every route, which
	 * would be a maintenance burden that goes stale the first time a module is
	 * installed.
	 */
	function index( event, rc, prc ){
		return respond(
			event = event,
			data  = {
				"name"    : "myCFCMS API",
				"version" : "v1",
				"site"    : {
					"name" : prc.currentSite.getName(),
					"slug" : prc.currentSite.getSlug()
				},
				"authentication" : {
					"type"   : "bearer",
					"header" : "Authorization: Bearer <token>",
					"issue"  : "/admin/api-tokens"
				}
			}
		);
	}

	/**
	 * Where `ApiHandler.fail()` sends a refused request.
	 *
	 * The response has already been rendered by then; this exists so the
	 * original action does not run. Overriding the event is what actually stops
	 * it — `noExecution()` alone left the protected action's output in the
	 * response, which is the bug that made a 403 leak a page's contents back in
	 * Group 5.
	 */
	function refused( event, rc, prc ){
		return;
	}

}
