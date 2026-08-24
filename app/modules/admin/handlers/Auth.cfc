/**
 * Signing in and out of a tenant's admin.
 */
component extends="core.models.security.SecuredHandler" {

	// Sign-in must be reachable without being signed in. Sign-out is deliberately
	// not public: it is a POST, and only a signed-in session has anything to end.
	variables.publicActions = "login,authenticate";
	variables.openActions   = "logout";

	function login( event, rc, prc ){
		// Already signed in: nothing to do here.
		if ( !isNull( authentication.getCurrentUser() ) ) {
			relocate( uri = "/admin" );
			return;
		}

		prc.pageTitle = "Sign in";
		event.setLayout( name = "Login", module = "core" ).setView( view = "auth/login", module = "admin" );
	}

	function authenticate( event, rc, prc ){
		// Public action, so preHandler's CSRF check does not run. Do it here:
		// the sign-in form is still a state-changing POST.
		if ( !csrf.verify( rc.csrfToken ?: "" ) ) {
			flash.put( "message", "That form has expired. Please try again." );
			flash.put( "messageType", "error" );
			relocate( uri = "/admin/login" );
			return;
		}

		try {
			authentication.login( rc.email ?: "", rc.password ?: "" );
		} catch ( Auth.InvalidCredentials e ) {
			flash.put( "message", "Those credentials are not valid." );
			flash.put( "messageType", "error" );
			flash.put( "email", rc.email ?: "" );
			relocate( uri = "/admin/login" );
			return;
		}

		// A new session id means the old token no longer belongs to anyone.
		csrf.rotate();

		var returnTo = flash.get( "returnTo", "" );

		if ( len( returnTo ) && isAdminPath( returnTo ) ) {
			relocate( uri = "/" & returnTo );
			return;
		}

		relocate( uri = "/admin" );
	}

	function logout( event, rc, prc ){
		authentication.logout();
		csrf.rotate();

		flash.put( "message", "You have been signed out." );
		relocate( uri = "/admin/login" );
	}

	/**
	 * Only ever return someone to a path inside this admin.
	 *
	 * The value came from a previous request, so treating it as a trusted
	 * redirect target would be an open redirect.
	 */
	private boolean function isAdminPath( required string path ){
		var candidate = reReplace( trim( arguments.path ), "^/+", "", "one" );

		return candidate == "admin" || left( candidate, 6 ) == "admin/";
	}

}
