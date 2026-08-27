/**
 * Google reCAPTCHA v2, for any public form on a site.
 *
 * In Core rather than in Contact because it is not a contact-form concern: a
 * comment box, a registration form or a sign-in page would all want the same
 * thing, and none of them should have to depend on the Contact module to get
 * it.
 *
 * ## Two keys, and only one of them may be rendered
 *
 * The **site key** is public by design — it goes in the HTML for the browser
 * to use. The **secret key** is a shared secret with Google, and anything that
 * puts it in a page, a form value or a JSON response has given it away. This
 * service therefore exposes `getSiteKey()` and deliberately has no public
 * accessor for the secret: `hasSecret()` answers whether one is set, and the
 * value itself is read only inside `verify()`, on the server, on its way to
 * Google.
 *
 * ## Configured means both keys
 *
 * A site with one key and not the other is misconfigured, not half-protected.
 * `isConfigured()` requires both, so a form either shows a working widget and
 * enforces it, or does neither — never renders a widget it cannot verify.
 *
 * ## Verification fails closed
 *
 * If Google cannot be reached, or answers something unexpected, `verify()`
 * reports failure. The alternative — accepting unverified submissions when the
 * check is unavailable — means an attacker gets a free pass by making the
 * check unavailable, which is the one condition under which it matters most.
 *
 * The cost is real and worth knowing: during a Google outage a site with
 * reCAPTCHA configured will reject genuine enquiries. The timeout is kept
 * short so that failure is quick rather than a hung request, and every refusal
 * is logged with its reason. A site that would rather take the spam can clear
 * the keys.
 */
component singleton accessors="true" {

	property name="settings" inject="SiteSettingsRepository@core";
	property name="log"      inject="logbox:logger:{this}";

	// Site settings keys. Constants because the admin screen writes the same
	// two, and a typo in either place would fail silently.
	this.KEY_SITE   = "recaptcha.siteKey";
	this.KEY_SECRET = "recaptcha.secretKey";

	variables.VERIFY_URL = "https://www.google.com/recaptcha/api/siteverify";

	// Short on purpose. A form submission is a person waiting, and a slow
	// failure is worse than a quick one.
	variables.TIMEOUT_SECONDS = 5;

	/**
	 * Is reCAPTCHA usable on this site?
	 *
	 * Both keys, or neither counts.
	 */
	boolean function isConfigured( required numeric siteId ){
		return len( getSiteKey( arguments.siteId ) ) && hasSecret( arguments.siteId );
	}

	/**
	 * The public key, safe to render into a page.
	 */
	string function getSiteKey( required numeric siteId ){
		return trim( settings.getValue( arguments.siteId, this.KEY_SITE, "" ) );
	}

	/**
	 * Whether a secret is set — never what it is.
	 *
	 * The admin needs to show "configured" without being able to display the
	 * value, and no caller has a legitimate reason for the secret itself.
	 */
	boolean function hasSecret( required numeric siteId ){
		return len( trim( settings.getValue( arguments.siteId, this.KEY_SECRET, "" ) ) ) > 0;
	}

	/**
	 * Check a token with Google.
	 *
	 * @token         The `g-recaptcha-response` value the widget put in the form.
	 * @remoteAddress The submitter's IP. Optional, and only ever a hint —
	 *                Google treats it as advisory and so does this.
	 *
	 * @return `{ success : boolean, configured : boolean, error : string }`.
	 *         `error` is written for a person, because it is shown to one.
	 */
	struct function verify(
		required numeric siteId,
		string token         = "",
		string remoteAddress = ""
	){
		// Nothing to check. Callers still ask, so that a form cannot be made to
		// skip verification by getting the order of its own checks wrong.
		if ( !isConfigured( arguments.siteId ) ) {
			return { "success" : true, "configured" : false, "error" : "" };
		}

		var presented = trim( arguments.token );

		if ( !len( presented ) ) {
			return {
				"success"    : false,
				"configured" : true,
				"error"      : "Please confirm you are not a robot."
			};
		}

		var secret = trim( settings.getValue( arguments.siteId, this.KEY_SECRET, "" ) );
		var body   = "";

		try {
			body = callVerifyEndpoint( secret, presented, trim( arguments.remoteAddress ) );
		} catch ( any e ) {
			log.error( "reCAPTCHA verification failed for site [#arguments.siteId#]: #e.message#" );

			return {
				"success"    : false,
				"configured" : true,
				"error"      : "We could not check that. Please try again in a moment."
			};
		}

		if ( !isJSON( body ) ) {
			// A proxy interception page, a captive portal, an outage — anything
			// that is not the JSON we asked for is not a pass.
			log.error( "reCAPTCHA returned a non-JSON response for site [#arguments.siteId#]: #left( body, 200 )#" );

			return {
				"success"    : false,
				"configured" : true,
				"error"      : "We could not check that. Please try again in a moment."
			};
		}

		var result = deserializeJSON( body );

		if ( result.success ?: false ) {
			return { "success" : true, "configured" : true, "error" : "" };
		}

		// Google's codes are for the log, not for the visitor: they distinguish
		// a bad secret from an expired token, which is useful to an operator
		// and meaningless to someone filling in a form.
		var codes = isArray( result[ "error-codes" ] ?: [] ) ? result[ "error-codes" ] : [];

		log.warn( "reCAPTCHA rejected a submission on site [#arguments.siteId#]: #codes.toList( ', ' )#" );

		return {
			"success"    : false,
			"configured" : true,
			"error"      : codes.findNoCase( "timeout-or-duplicate" )
				? "That check expired. Please tick the box again."
				: "That check did not pass. Please try again."
		};
	}

	/**
	 * The call to Google, on its own so it can be replaced in a test.
	 *
	 * Extracted purely as a seam: the behaviour worth pinning down is what this
	 * service does when the call *fails*, and a spec that reaches the real
	 * endpoint to find out would be slow, flaky and dependent on someone else's
	 * uptime.
	 *
	 * @return The raw response body.
	 */
	private string function callVerifyEndpoint(
		required string secret,
		required string token,
		string remoteAddress = ""
	){
		var answer = "";

		cfhttp(
			url     = variables.VERIFY_URL,
			method  = "POST",
			timeout = variables.TIMEOUT_SECONDS,
			result  = "answer"
		) {
			cfhttpparam( type = "formfield", name = "secret", value = arguments.secret );
			cfhttpparam( type = "formfield", name = "response", value = arguments.token );

			if ( len( arguments.remoteAddress ) ) {
				cfhttpparam( type = "formfield", name = "remoteip", value = arguments.remoteAddress );
			}
		}

		return answer.fileContent ?: "";
	}

}
