/**
 * Issuing and revoking API tokens.
 *
 * The one screen in the admin that shows a secret, and it shows it exactly
 * once. Nothing here can recover a token afterwards, because nothing anywhere
 * can: only a hash is stored.
 */
component extends="core.models.security.SecuredHandler" {

	property name="apiTokens" inject="ApiTokenService@core";
	property name="users"     inject="UserService@core";

	variables.permissions = {
		"index"  : "api.tokens.manage",
		"issue"  : "api.tokens.manage",
		"revoke" : "api.tokens.manage",
		"remove" : "api.tokens.manage",
		"$every" : "api.tokens.manage"
	};

	function index( event, rc, prc ){
		var siteId = prc.currentSite.getId();

		prc.pageTitle = "API tokens";
		prc.tokens    = apiTokens.getForSite( siteId );
		prc.users     = users.getUsersForSite( siteId );

		// Carried through the flash from `issue()`, and shown once. Never read
		// back from the database, because it is not there.
		prc.newToken = flash.get( "newToken", "" );
		prc.newName  = flash.get( "newName", "" );

		event.setView( view = "apiTokens/index", module = "admin" );
	}

	function issue( event, rc, prc ){
		try {
			var expires = javacast( "null", "" );

			if ( len( trim( rc.expiresAt ?: "" ) ) && isDate( rc.expiresAt ) ) {
				expires = parseDateTime( rc.expiresAt );
			}

			var token = isNull( expires )
				? apiTokens.issue(
					siteId = prc.currentSite.getId(),
					userId = val( rc.userId ?: 0 ),
					name   = rc.name ?: ""
				)
				: apiTokens.issue(
					siteId    = prc.currentSite.getId(),
					userId    = val( rc.userId ?: 0 ),
					name      = rc.name ?: "",
					expiresAt = expires
				);
		} catch ( any e ) {
			return done( "/admin/api-tokens", e.message, "error" );
		}

		flash.put( "newToken", token.getPlainToken() );
		flash.put( "newName", token.getName() );

		return done( "/admin/api-tokens", "Token issued. Copy it now — it cannot be shown again." );
	}

	function revoke( event, rc, prc ){
		try {
			apiTokens.revoke( val( rc.id ?: 0 ), prc.currentSite.getId() );
		} catch ( any e ) {
			return done( "/admin/api-tokens", e.message, "error" );
		}

		return done( "/admin/api-tokens", "Token revoked. Any client using it stops working immediately." );
	}

	function remove( event, rc, prc ){
		try {
			apiTokens.deleteToken( val( rc.id ?: 0 ), prc.currentSite.getId() );
		} catch ( any e ) {
			return done( "/admin/api-tokens", e.message, "error" );
		}

		return done( "/admin/api-tokens", "Token deleted." );
	}

}
