/**
 * Serves the public will wizard and receives the completed POST.
 *
 *     /will             the wizard
 *     /will/thank-you   after a successful send
 */
component singleton accessors="true" {

	property name="willService" inject="WillService@will";
	property name="csrf"        inject="CsrfService@core";
	property name="recaptcha"   inject="RecaptchaService@core";
	property name="settings"    inject="coldbox:moduleSettings:will";
	property name="log"         inject="logbox:logger:{this}";

	function resolveContent( required numeric siteId, required string path ){
		var base = basePath();

		if ( !len( base ) ) {
			return;
		}

		if ( arguments.path == base ) {
			return formResolution( arguments.siteId );
		}

		if ( arguments.path == base & "/" & thankYouSegment() ) {
			return thankYouResolution();
		}

		return;
	}

	function handleSubmission(
		required numeric siteId,
		required string path,
		required struct formData
	){
		if ( arguments.path != basePath() ) {
			return;
		}

		if ( !csrf.verify( arguments.formData.csrfToken ?: "" ) ) {
			return failed( arguments.siteId, arguments.formData, [ "That form expired. Please try again." ] );
		}

		if ( len( trim( arguments.formData[ honeypotField() ] ?: "" ) ) ) {
			log.warn( "Will honeypot tripped on site [#arguments.siteId#]." );
			return { "redirectTo" : "/" & basePath() & "/" & thankYouSegment() };
		}

		if ( requireRecaptcha() ) {
			var challenge = recaptcha.verify(
				siteId        = arguments.siteId,
				token         = arguments.formData[ "g-recaptcha-response" ] ?: "",
				remoteAddress = senderAddress()
			);

			if ( !challenge.success ) {
				return failed( arguments.siteId, arguments.formData, [ challenge.error ] );
			}
		}

		var errors = willService.validateSubmission( arguments.formData );

		if ( errors.len() ) {
			return failed( arguments.siteId, arguments.formData, errors );
		}

		try {
			willService.submit(
				siteId    = arguments.siteId,
				values    = arguments.formData,
				ipAddress = senderAddress(),
				userAgent = cgi.http_user_agent ?: ""
			);
		} catch ( Will.InvalidSubmission e ) {
			return failed( arguments.siteId, arguments.formData, [ e.message ] );
		}

		return { "redirectTo" : "/" & basePath() & "/" & thankYouSegment() };
	}

	private function formResolution( required numeric siteId ){
		return {
			"view" : "will-form",
			"args" : formArgs( arguments.siteId, {}, [] ),
			"title"           : "Create your will",
			"metaDescription" : "",
			"statusCode"      : 200,
			"robots"          : "noindex"
		};
	}

	private function thankYouResolution(){
		return {
			"view"            : "will-sent",
			"args"            : {},
			"title"           : "Thank you",
			"metaDescription" : "",
			"statusCode"      : 200,
			"robots"          : "noindex"
		};
	}

	private function failed( required numeric siteId, required struct values, required array errors ){
		return {
			"view" : "will-form",
			"args" : formArgs( arguments.siteId, arguments.values, arguments.errors ),
			"title"           : "Create your will",
			"metaDescription" : "",
			"statusCode"      : 422,
			"robots"          : "noindex"
		};
	}

	private struct function formArgs( required numeric siteId, required struct values, required array errors ){
		return {
			"errors"           : arguments.errors,
			"values"           : arguments.values,
			"csrfToken"        : csrf.getCurrentToken(),
			"honeypotField"    : honeypotField(),
			"action"           : "/" & basePath(),
			"recaptchaSiteKey" : siteKeyFor( arguments.siteId )
		};
	}

	private string function siteKeyFor( required numeric siteId ){
		if ( !requireRecaptcha() ) {
			return "";
		}

		return recaptcha.isConfigured( arguments.siteId ) ? recaptcha.getSiteKey( arguments.siteId ) : "";
	}

	private boolean function requireRecaptcha(){
		return settings.requireRecaptcha ?: false;
	}

	private string function senderAddress(){
		if ( settings.trustForwardedFor ?: false ) {
			var forwarded = trim( listFirst( cgi.http_x_forwarded_for ?: "" ) );

			if ( len( forwarded ) ) {
				return forwarded;
			}
		}

		return cgi.remote_addr ?: "";
	}

	private string function basePath(){
		return reReplace( lCase( trim( settings.basePath ?: "will" ) ), "^/+|/+$", "", "all" );
	}

	private string function thankYouSegment(){
		return reReplace( lCase( trim( settings.thankYouSegment ?: "thank-you" ) ), "^/+|/+$", "", "all" );
	}

	private string function honeypotField(){
		return settings.honeypotField ?: "website";
	}

}
