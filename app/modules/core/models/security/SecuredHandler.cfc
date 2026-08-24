/**
 * The request boundary where authentication and authorisation are enforced.
 *
 * Lives in Core, not in the admin module, so that any module can secure its own
 * screens by extending it. Pages contributes admin screens under /admin/pages
 * and depends on Core alone; it never has to depend on the admin module to
 * borrow a base class.
 *
 * Groups 2 and 3 deliberately kept permission checks out of the services, so a
 * CLI task or a migration could call them. This is where that decision is paid
 * off: every admin screen runs through one `preHandler`, and a screen cannot
 * forget to check, because not declaring a permission is itself a decision the
 * handler has to make explicitly.
 *
 * Handlers declare what each action needs:
 *
 *     variables.permissions = {
 *         "index"  : "pages.view",
 *         "save"   : "pages.update",
 *         "$every" : "pages.view"     // fallback for unlisted actions
 *     };
 *
 * An action with no entry and no `$every` fallback is refused rather than
 * allowed: forgetting to declare a permission must fail closed.
 */
component extends="coldbox.system.EventHandler" {

	property name="authentication" inject="AuthenticationService@core";
	property name="authorization"  inject="AuthorizationService@core";
	property name="tenantContext"  inject="TenantContext@core";
	property name="csrf"           inject="CsrfService@core";
	property name="adminNav"       inject="AdminNavigationRegistry@core";

	// Actions reachable without signing in. Anything not listed requires a user.
	variables.publicActions = "";

	// Actions that may be reached by any signed-in user, whatever their roles.
	variables.openActions = "";

	// action -> permission slug. `$every` is the fallback.
	variables.permissions = {};

	function preHandler( event, rc, prc, action, eventArguments ){
		// The admin only exists inside a tenant. Without one there is no site to
		// administer and no user directory to sign in against.
		if ( !tenantContext.hasCurrentTenant() ) {
			return refuse( event, "core:Security.unknownDomain" );
		}


		prc.currentSite = tenantContext.getCurrentTenant();
		prc.csrfToken   = csrf.getCurrentToken();

		// The admin chrome lives in Core, so a module's admin screens inherit it
		// without depending on the admin module.
		event.setLayout( name = "Admin", module = "core" );

		if ( listFindNoCase( variables.publicActions, arguments.action ) ) {
			return;
		}

		var user = authentication.getCurrentUser();

		if ( isNull( user ) ) {
			// Come back here after signing in, rather than dumping the user on
			// the dashboard and making them navigate again.
			flash.put( "returnTo", event.getCurrentRoutedURL() );
			// relocate() ends the request outright, so no diversion is needed.
			relocate( uri = "/admin/login" );
			return;
		}

		prc.currentUser = user;
		prc.adminNav    = adminNav.getGroupedSectionsFor( user, authorization );
		prc.currentPath = "/" & reReplace( event.getCurrentRoutedURL(), "^/+|/+$", "", "all" );

		// Any state-changing request must carry the session's CSRF token.
		if ( isMutating( event ) && !csrf.verify( submittedToken( event, rc ) ) ) {
			return refuse( event, "core:Security.expired" );
		}

		if ( listFindNoCase( variables.openActions, arguments.action ) ) {
			return;
		}

		var required = requiredPermissionFor( arguments.action );

		if ( !len( required ) || !authorization.can( user, required ) ) {
			prc.deniedPermission = required;
			return refuse( event, "core:Security.forbidden" );
		}
	}

	/**
	 * Turn "no such record here" into a clean 404 inside the admin.
	 *
	 * The tenant guards in every admin handler throw `Admin.NotFoundHere` when
	 * an id in the URL is unknown or belongs to another site. Unhandled, that
	 * surfaced as a 500 with a full stack trace — so tampering with an id in
	 * the address bar returned an error page describing the application's
	 * internals.
	 *
	 * Anything else is rethrown untouched, so genuine faults still reach the
	 * framework's exception handling and the log rather than being swallowed
	 * behind a friendly page.
	 */
	function onError( event, rc, prc, faultAction, exception ){
		var thrownType = structKeyExists( arguments.exception, "type" ) ? arguments.exception.type : "";

		if ( thrownType != "Admin.NotFoundHere" ) {
			// `rethrow` is only valid inside a catch block, and this is not one:
			// using it here threw an error of its own and turned every fault
			// into a 500. Rethrowing the object works anywhere.
			throw( object = arguments.exception );
		}

		event.setHTTPHeader( statusCode = 404, statusText = "Not Found" );

		prc.pageTitle = "Not found";
		event.setLayout( name = "Admin", module = "core" )
			.setView( view = "errors/notFoundHere", module = "core" );
	}

	/**
	 * Divert this request away from the action it asked for.
	 *
	 * `event.noExecution()` is deliberately not used. ColdBox's
	 * `Controller.runEvent()` invokes the action after `preHandler` without
	 * consulting that flag, so refusing that way still ran — and rendered — the
	 * protected action behind a 403 header. Overriding the event works because
	 * the Controller re-resolves the handler when the event has changed.
	 */
	private function refuse( required any event, required string target ){
		arguments.event.overrideEvent( arguments.target );
		return this;
	}

	/**
	 * The permission an action needs, or an empty string when none is declared.
	 *
	 * An empty result denies. A handler that means "any signed-in user" says so
	 * through `openActions`, so the permissive case is always deliberate.
	 */
	private string function requiredPermissionFor( required string action ){
		if ( structKeyExists( variables.permissions, arguments.action ) ) {
			return variables.permissions[ arguments.action ];
		}

		return variables.permissions[ "$every" ] ?: "";
	}

	/**
	 * The CSRF token, from wherever this request could carry one.
	 *
	 * A form posts it as a field. A script-driven upload — the editor's image
	 * button — has no form to put it in, so it sends a header instead. Both are
	 * the same session token and are checked the same way; only the transport
	 * differs.
	 */
	private string function submittedToken( event, rc ){
		var fromField = arguments.rc.csrfToken ?: "";

		if ( len( fromField ) ) {
			return fromField;
		}

		return arguments.event.getHTTPHeader( "X-CSRF-Token", "" );
	}

	private boolean function isMutating( event ){
		return listFindNoCase( "POST,PUT,PATCH,DELETE", arguments.event.getHTTPMethod() ) > 0;
	}

	/**
	 * Redirect back to a screen with a message for the user.
	 */
	private function done(
		required string uri,
		string message = "",
		string type    = "success"
	){
		if ( len( arguments.message ) ) {
			flash.put( "message", arguments.message );
			flash.put( "messageType", arguments.type );
		}

		relocate( uri = arguments.uri );

		return this;
	}

}
