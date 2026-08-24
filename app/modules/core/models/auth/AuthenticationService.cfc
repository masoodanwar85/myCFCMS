/**
 * Signing in and out.
 *
 * This is the piece Group 2 deliberately left out. Group 2 stopped at
 * "does this password match this hash?"; establishing an identity and carrying
 * it across requests needed the request boundary that Group 5 introduces.
 *
 * Identity is always scoped to the tenant the request resolved to. A session
 * records both who signed in and which site they signed in at, and both must
 * still hold on every subsequent request — so a session cannot be carried from
 * one tenant to another even if a cookie somehow reaches both.
 */
component singleton accessors="true" {

	property name="userRepository"  inject="UserRepository@core";
	property name="passwordService" inject="PasswordService@core";
	property name="tenantContext"   inject="TenantContext@core";
	property name="log"             inject="logbox:logger:{this}";

	variables.SESSION_USER_KEY = "cms_authUserId";
	variables.SESSION_SITE_KEY = "cms_authSiteId";

	// Cached for the duration of one request, so a page that asks five times
	// does not issue five queries.
	variables.REQUEST_USER_KEY = "cms_authCurrentUser";

	/**
	 * Sign in against the current tenant.
	 *
	 * A site's own user is looked up first, then a platform super admin, so an
	 * admin can sign in on any client's domain.
	 *
	 * Every failure raises the same error with the same message. Distinguishing
	 * "no such account" from "wrong password" would turn this into a way of
	 * discovering who has an account on a client's site.
	 *
	 * @throws Auth.NoTenant           when the host resolved to no site.
	 * @throws Auth.InvalidCredentials for every authentication failure.
	 */
	core.models.auth.User function login( required string email, required string password ){
		if ( !tenantContext.hasCurrentTenant() ) {
			throw(
				type    = "Auth.NoTenant",
				message = "Cannot sign in: this host is not a configured site."
			);
		}

		var site         = tenantContext.getCurrentTenant();
		var emailAddress = lCase( trim( arguments.email ) );
		var user         = userRepository.findByEmailForSite( emailAddress, site.getId() );

		if ( isNull( user ) ) {
			user = userRepository.findSuperAdminByEmail( emailAddress );
		}

		if ( isNull( user ) || !user.isActive() || !passwordService.verify( arguments.password, user.getPasswordHash() ) ) {
			log.warn( "Failed sign-in for [#emailAddress#] on site [#site.getId()#]." );
			throw(
				type    = "Auth.InvalidCredentials",
				message = "Those credentials are not valid."
			);
		}

		startSessionFor( user, site.getId() );

		log.info( "User [#user.getId()#] signed in on site [#site.getId()#]." );

		return user;
	}

	function logout(){
		structDelete( session, variables.SESSION_USER_KEY );
		structDelete( session, variables.SESSION_SITE_KEY );
		structDelete( request, variables.REQUEST_USER_KEY );

		rotateSessionId();

		return this;
	}

	boolean function isLoggedIn(){
		return !isNull( getCurrentUser() );
	}

	/**
	 * The signed-in user, re-validated against the current request.
	 *
	 * Returns null — and clears the session — when anything no longer holds:
	 * the account was deleted or deactivated since sign-in, or the session
	 * belongs to a different tenant than this request resolved to.
	 *
	 * @return User, or null.
	 */
	function getCurrentUser(){
		if ( structKeyExists( request, variables.REQUEST_USER_KEY ) ) {
			return request[ variables.REQUEST_USER_KEY ];
		}

		if ( !structKeyExists( session, variables.SESSION_USER_KEY ) ) {
			return;
		}

		if ( !tenantContext.hasCurrentTenant() ) {
			return;
		}

		// The session must belong to the tenant serving this request.
		if ( ( session[ variables.SESSION_SITE_KEY ] ?: 0 ) != tenantContext.getCurrentTenantId() ) {
			logout();
			return;
		}

		var user = userRepository.findById( session[ variables.SESSION_USER_KEY ] );

		if ( isNull( user ) || !user.isActive() ) {
			logout();
			return;
		}

		// A site user whose account was moved, or a stale session after a
		// tenant change, must not keep acting on this site.
		if ( !user.belongsToSite( tenantContext.getCurrentTenantId() ) ) {
			logout();
			return;
		}

		request[ variables.REQUEST_USER_KEY ] = user;

		return user;
	}

	/**
	 * @throws Auth.NotAuthenticated
	 */
	core.models.auth.User function requireCurrentUser(){
		var user = getCurrentUser();

		if ( isNull( user ) ) {
			throw( type = "Auth.NotAuthenticated", message = "This action requires a signed-in user." );
		}

		return user;
	}

	/**
	 * Establish a session for a user who has already been authenticated.
	 *
	 * Separated from `login` so tests and future flows — an invitation link,
	 * an SSO callback — can reuse it without going through a password.
	 */
	function startSessionFor( required core.models.auth.User user, required numeric siteId ){
		// New identity, new session id: otherwise a session id captured before
		// sign-in is still valid afterwards.
		rotateSessionId();

		session[ variables.SESSION_USER_KEY ] = arguments.user.getId();
		session[ variables.SESSION_SITE_KEY ] = arguments.siteId;

		structDelete( request, variables.REQUEST_USER_KEY );

		return this;
	}

	/**
	 * Session fixation defence. Not every engine exposes it, and a missing
	 * rotate must not stop someone signing in.
	 */
	private function rotateSessionId(){
		try {
			sessionRotate();
		} catch ( any e ) {
			log.debug( "sessionRotate() unavailable: #e.message#" );
		}

		return this;
	}

}
