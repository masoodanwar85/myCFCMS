/**
 * Cross-site request forgery tokens.
 *
 * The admin runs on the same domain a client's visitors browse, and its forms
 * change data with a session cookie the browser attaches automatically. Without
 * a token, any page on the internet could post to them on a signed-in user's
 * behalf.
 *
 * One token per session, rotated on sign-in and sign-out, which is enough for
 * server-rendered forms. Per-form tokens would be stronger and would break the
 * back button and multiple tabs, which is a poor trade for an admin UI.
 */
component singleton accessors="true" {

	variables.SESSION_KEY = "cms_csrfToken";

	/**
	 * The current session's token, generated on first use.
	 *
	 * Named `getCurrentToken` rather than `getToken`: CFML has a built-in
	 * `getToken( string, index )`, and declaring a component method with that
	 * name collides with it.
	 */
	string function getCurrentToken(){
		if ( !structKeyExists( session, variables.SESSION_KEY ) || !len( session[ variables.SESSION_KEY ] ) ) {
			session[ variables.SESSION_KEY ] = generateToken();
		}

		return session[ variables.SESSION_KEY ];
	}

	/**
	 * Constant-time comparison, so a token cannot be discovered a character at
	 * a time by timing the response.
	 */
	boolean function verify( string token = "" ){
		var expected = getCurrentToken();
		var supplied = arguments.token ?: "";

		if ( len( supplied ) != len( expected ) ) {
			return false;
		}

		var difference = 0;

		for ( var i = 1; i <= len( expected ); i++ ) {
			difference = bitOr( difference, bitXor( asc( mid( expected, i, 1 ) ), asc( mid( supplied, i, 1 ) ) ) );
		}

		return difference == 0;
	}

	/**
	 * @throws Security.InvalidCsrfToken
	 */
	function assertValid( string token = "" ){
		if ( !verify( arguments.token ) ) {
			throw(
				type    = "Security.InvalidCsrfToken",
				message = "This form has expired. Please try again.",
				detail  = "The submitted CSRF token did not match the session's."
			);
		}

		return this;
	}

	function rotate(){
		session[ variables.SESSION_KEY ] = generateToken();
		return this;
	}

	/**
	 * A hidden input carrying the token, for a form to include.
	 */
	string function getFormField(){
		return '<input type="hidden" name="csrfToken" value="' & encodeForHTMLAttribute( getCurrentToken() ) & '">';
	}

	private string function generateToken(){
		return lCase( hash( createUUID() & getTickCount() & createUUID(), "SHA-256" ) );
	}

}
