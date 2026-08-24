/**
 * The screens a refused request is diverted to.
 *
 * SecuredHandler cannot simply decline to run an action: ColdBox's
 * `Controller.runEvent()` calls `preHandler` and then invokes the action
 * regardless — `event.noExecution()` is not consulted on that path. Setting a
 * 403 header there would have produced a 403 response containing the very page
 * the user was not allowed to see.
 *
 * Overriding the event is the mechanism that does work: the Controller
 * re-resolves the handler after `preHandler` when the event has changed, so
 * execution lands here instead of on the protected action.
 */
component extends="coldbox.system.EventHandler" {

	/**
	 * Signed in, but this action is not permitted.
	 */
	function forbidden( event, rc, prc ){
		event.setHTTPHeader( statusCode = 403, statusText = "Forbidden" );
		prc.pageTitle = "Not allowed";
		event.setView( view = "errors/forbidden", module = "core" );
	}

	/**
	 * The submitted CSRF token did not match the session's.
	 */
	function expired( event, rc, prc ){
		event.setHTTPHeader( statusCode = 419, statusText = "Expired" );
		prc.pageTitle = "Expired";
		event.setView( view = "errors/expired", module = "core" );
	}

	/**
	 * The host does not resolve to a site, so there is nothing to administer.
	 */
	function unknownDomain( event, rc, prc ){
		event.setHTTPHeader( statusCode = 404, statusText = "Not Found" );
		prc.requestedHost = cgi.http_host ?: "";
		event.noLayout().setView( view = "frontend/unknownDomain", module = "core" );
	}

}
