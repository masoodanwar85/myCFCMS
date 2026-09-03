/**
 * Receives what people send through an embedded form.
 *
 * Claims **no URLs of its own**: a form lives wherever an author put the
 * shortcode, and giving forms their own routes as well would mean two addresses
 * for the same thing.
 *
 * `resolveContent` is therefore present and always returns null. It cannot be
 * omitted: `ContentResolverRegistry.resolve()` calls it on every registered
 * resolver without checking it exists, while `resolveSubmission()` guards with
 * `structKeyExists` first. Rather than change Core to suit one module — the
 * thing these seams exist to avoid — the method is declared here and says why.
 *
 * What it does own is the POST. An embedded form posts back to the page it sits
 * on — a page Pages owns — so this resolver claims that submission when, and
 * only when, it carries a marker naming an active form for this site. Without
 * the marker the request is left alone and the page renders as usual.
 *
 * Both outcomes answer with a redirect and leave their state in flash, because
 * this resolver cannot re-render somebody else's page. That also means a
 * refused response cannot be re-posted by refreshing.
 */
component singleton accessors="true" {

	property name="formService" inject="FormService@forms";
	property name="csrf"        inject="CsrfService@core";
	property name="recaptcha"   inject="RecaptchaService@core";
	property name="settings"    inject="coldbox:moduleSettings:forms";
	property name="flash"       inject="coldbox:flash";
	property name="log"         inject="logbox:logger:{this}";

	/**
	 * The marker an embedded form posts, naming which form is answering.
	 *
	 * Distinct from Contact's `form` field on purpose: a page may carry both a
	 * contact form and one of these, and two modules reading the same key from
	 * the same POST would both try to claim it.
	 */
	variables.MARKER = "cmsForm";

	/**
	 * No URL belongs to this module, so every path falls through to whoever
	 * does own it. See the note at the top of this file for why the method is
	 * here at all.
	 */
	function resolveContent( required numeric siteId, required string path ){
		return;
	}

	/**
	 * @return A resolution when this POST is ours, or null to leave it alone.
	 */
	function handleSubmission(
		required numeric siteId,
		required string path,
		required struct formData
	){
		var slug = trim( arguments.formData[ variables.MARKER ] ?: "" );

		if ( !len( slug ) ) {
			return;
		}

		// `true`: a form switched off must not accept responses. Looking it up
		// without that check is how a deactivated form keeps taking mail.
		var built = formService.getFormBySlug( arguments.siteId, slug, true );

		if ( isNull( built ) ) {
			return;
		}

		// A token proves the form came from a session that was actually served
		// this page. Without it, anything on the internet could post here.
		if ( !csrf.verify( arguments.formData.csrfToken ?: "" ) ) {
			return refuse( arguments.path, built, arguments.formData, [ "That form expired. Please try again." ] );
		}

		// A field a person never sees and never fills in.
		if ( len( trim( arguments.formData[ honeypotField() ] ?: "" ) ) ) {
			log.warn( "Form honeypot tripped on site [#arguments.siteId#], form [#built.getSlug()#]." );

			// Answered exactly as a success would be, so a bot learns nothing.
			return succeed( arguments.path, built );
		}

		var challenge = recaptcha.verify(
			siteId        = arguments.siteId,
			token         = arguments.formData[ "g-recaptcha-response" ] ?: "",
			remoteAddress = senderAddress()
		);

		if ( !challenge.success ) {
			return refuse( arguments.path, built, arguments.formData, [ challenge.error ] );
		}

		try {
			formService.submit(
				form      = built,
				values    = arguments.formData,
				ipAddress = senderAddress(),
				userAgent = cgi.http_user_agent ?: ""
			);
		} catch ( Forms.TooManySubmissions e ) {
			return refuse( arguments.path, built, arguments.formData, [ e.message ] );
		} catch ( Forms.InvalidSubmission e ) {
			return refuse( arguments.path, built, arguments.formData, [ e.message ] );
		} catch ( Forms.FormInactive e ) {
			return refuse( arguments.path, built, arguments.formData, [ e.message ] );
		}

		return succeed( arguments.path, built );
	}

	/* -------------------------------------------------------------- outcomes */

	private struct function succeed( required string path, required forms.models.Form form ){
		var configured = arguments.form.getThankYouPath() ?: "";

		if ( len( configured ) ) {
			return { "redirectTo" : configured };
		}

		flashFor( arguments.form, {
			"sent"    : true,
			"message" : arguments.form.getSuccessMessage()
		} );

		return { "redirectTo" : "/" & arguments.path };
	}

	private struct function refuse(
		required string path,
		required forms.models.Form form,
		required struct values,
		required array errors
	){
		flashFor( arguments.form, {
			"sent"   : false,
			"errors" : arguments.errors,
			// Only the form's own fields. Flashing the whole post would put the
			// CSRF token and the reCAPTCHA response into the session and back
			// into the next page.
			"values" : answeredValues( arguments.form, arguments.values )
		} );

		return { "redirectTo" : "/" & arguments.path };
	}

	/**
	 * What the visitor typed, so the redisplayed form is not blank.
	 */
	private struct function answeredValues( required forms.models.Form form, required struct values ){
		var kept = {};

		for ( var field in arguments.form.getFields() ) {
			var key = field.getFieldKey();

			if ( structKeyExists( arguments.values, key ) ) {
				kept[ key ] = arguments.values[ key ];
			}
		}

		return kept;
	}

	/**
	 * Keyed by form slug, so two forms on one page cannot show each other's
	 * message, and so a form's outcome cannot be read by the contact form.
	 */
	private function flashFor( required forms.models.Form form, required struct state ){
		flash.put( flashKey( arguments.form.getSlug() ), arguments.state );

		return this;
	}

	string function flashKey( required string slug ){
		return "cmsForm_" & arguments.slug;
	}

	string function markerField(){
		return variables.MARKER;
	}

	/* --------------------------------------------------------------- helpers */

	private string function honeypotField(){
		return settings.honeypotField ?: "website";
	}

	/**
	 * The sender's address, preferring a proxy header only when the deployment
	 * says it sits behind a proxy that sets one — `X-Forwarded-For` is
	 * trivially forged.
	 */
	private string function senderAddress(){
		if ( settings.trustForwardedFor ?: false ) {
			var forwarded = trim( listFirst( cgi.http_x_forwarded_for ?: "" ) );

			if ( len( forwarded ) ) {
				return forwarded;
			}
		}

		return cgi.remote_addr ?: "";
	}

}
