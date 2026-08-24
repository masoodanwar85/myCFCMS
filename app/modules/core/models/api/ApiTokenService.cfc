/**
 * Issuing, verifying and revoking API tokens.
 *
 * ## Generating one
 *
 * 32 bytes from `java.security.SecureRandom`, hex-encoded, behind a fixed
 * `cms_` prefix so a leaked token is recognisable for what it is — secret
 * scanners key off exactly that, and a token that can be spotted in a public
 * repository is a token that can be revoked before it is used.
 *
 * **Not `createUUID()`.** A UUID looks random and is not required to be
 * unpredictable; using one as a credential is a well-worn mistake.
 *
 * ## Verifying one
 *
 * The presented token is hashed and looked up by hash. Nothing compares
 * secrets, so there is no string comparison to time — the only thing an
 * attacker can learn from a failed request is that their hash was not in a
 * unique index.
 */
component singleton accessors="true" {

	property name="tokens"        inject="ApiTokenRepository@core";
	property name="users"         inject="UserRepository@core";
	property name="siteRepo"      inject="SiteRepository@core";
	property name="authorization" inject="AuthorizationService@core";
	property name="wirebox"       inject="wirebox";
	property name="log"           inject="logbox:logger:{this}";

	// Recognisable at a glance, and greppable by a secret scanner.
	this.PREFIX = "cms_";

	// Bytes of entropy. 32 is 256 bits — far beyond anything brute-forceable,
	// and the same size the hash it is stored under produces.
	variables.BYTES = 32;

	// How much of the token the admin may display.
	variables.PREFIX_SHOWN = 12;

	/**
	 * Issue a token for a user on a site.
	 *
	 * The returned object is the **only** time the plain token exists. It is
	 * not stored and cannot be recovered.
	 *
	 * @expiresAt Optional. A token with no expiry is a credential that outlives
	 *            everyone who remembers creating it, so the admin encourages
	 *            one — but does not force it, because a deploy pipeline that
	 *            breaks at 3am on a Sunday is its own kind of outage.
	 *
	 * @throws Api.SiteNotFound
	 * @throws Api.UserNotFound
	 * @throws Api.InvalidToken
	 * @throws Api.CrossTenantUser
	 */
	core.models.api.ApiToken function issue(
		required numeric siteId,
		required numeric userId,
		required string name,
		any expiresAt
	){
		if ( isNull( siteRepo.findById( arguments.siteId ) ) ) {
			throw( type = "Api.SiteNotFound", message = "No site with id [#arguments.siteId#]." );
		}

		var user = users.findById( arguments.userId );

		if ( isNull( user ) ) {
			throw( type = "Api.UserNotFound", message = "No user with id [#arguments.userId#]." );
		}

		// A super admin has no site of their own and may act on any; anyone
		// else must belong to the site the token is for.
		if ( !user.isSuperAdmin() && val( user.getSiteId() ?: 0 ) != arguments.siteId ) {
			throw(
				type    = "Api.CrossTenantUser",
				message = "A token cannot be issued to a user from another site."
			);
		}

		var label = trim( arguments.name );

		if ( !len( label ) ) {
			throw( type = "Api.InvalidToken", message = "A token needs a name, so it can be recognised later." );
		}

		var plain = generate();

		var token = wirebox
			.getInstance( "ApiToken@core" )
			.setSiteId( arguments.siteId )
			.setUserId( arguments.userId )
			.setName( label )
			.setTokenHash( hashToken( plain ) )
			.setPrefix( left( plain, variables.PREFIX_SHOWN ) );

		if ( !isNull( arguments.expiresAt ) && isDate( arguments.expiresAt ) ) {
			token.setExpiresAt( arguments.expiresAt );
		}

		tokens.create( token );

		// Set last, so it cannot end up in the row by accident.
		token.setPlainToken( plain );

		return token;
	}

	/**
	 * Resolve a presented token to the user it authorises.
	 *
	 * @return `{ token, user, site }`, or null for anything not currently
	 *         usable. The caller gets one answer for "no such token", "revoked",
	 *         "expired" and "the user is deactivated" — an API should not help
	 *         someone work out which of those they have found.
	 */
	function resolve( required string presented ){
		var candidate = trim( arguments.presented );

		if ( !len( candidate ) ) {
			return;
		}

		var token = tokens.findByHash( hashToken( candidate ) );

		if ( isNull( token ) || !token.isActive() ) {
			return;
		}

		var user = users.findById( token.getUserId() );

		if ( isNull( user ) || !user.isActive() ) {
			return;
		}

		var site = siteRepo.findById( token.getSiteId() );

		if ( isNull( site ) || !site.isActive() ) {
			return;
		}

		tokens.touch( token.getId() );

		return { "token" : token, "user" : user, "site" : site };
	}

	array function getForSite( required numeric siteId ){
		return tokens.findBySiteId( arguments.siteId );
	}

	/**
	 * @throws Api.TokenNotFound
	 */
	function revoke( required numeric tokenId, required numeric siteId ){
		var token = tokens.findById( arguments.tokenId );

		if ( isNull( token ) || token.getSiteId() != arguments.siteId ) {
			throw( type = "Api.TokenNotFound", message = "No token with id [#arguments.tokenId#] on this site." );
		}

		tokens.revoke( token.getId() );

		return this;
	}

	/**
	 * @throws Api.TokenNotFound
	 */
	function deleteToken( required numeric tokenId, required numeric siteId ){
		var token = tokens.findById( arguments.tokenId );

		if ( isNull( token ) || token.getSiteId() != arguments.siteId ) {
			throw( type = "Api.TokenNotFound", message = "No token with id [#arguments.tokenId#] on this site." );
		}

		tokens.delete( token.getId() );

		return this;
	}

	/* --------------------------------------------------------------------- */

	/**
	 * `cms_` plus 64 hex characters of cryptographic randomness.
	 */
	private string function generate(){
		var random = createObject( "java", "java.security.SecureRandom" ).init();
		var bytes  = javacast( "byte[]", [] );

		bytes = repeatByteArray( variables.BYTES );
		random.nextBytes( bytes );

		return this.PREFIX & lCase( binaryEncode( bytes, "hex" ) );
	}

	private function repeatByteArray( required numeric size ){
		// `SecureRandom.nextBytes` fills an array in place, so one of the right
		// length has to exist first.
		return createObject( "java", "java.lang.reflect.Array" )
			.newInstance( createObject( "java", "java.lang.Byte" ).TYPE, javacast( "int", arguments.size ) );
	}

	/**
	 * SHA-256 of the presented token.
	 *
	 * Named `hashToken`, not `hash`: ColdFusion has a built-in `hash()`, and an
	 * unqualified call inside this component would resolve to the BIF rather
	 * than to this method. The same trap `PasswordService.hashPassword` avoids.
	 */
	string function hashToken( required string plain ){
		return lCase( hash( arguments.plain, "SHA-256", "utf-8" ) );
	}

}
