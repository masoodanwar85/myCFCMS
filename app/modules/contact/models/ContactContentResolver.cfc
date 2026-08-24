/**
 * Serves the public contact form and receives what visitors send.
 *
 * Claims two URLs under the module's base path:
 *
 *     /contact             the form, and where it posts back to
 *     /contact/thank-you   after a successful send
 *
 * The separate thank-you URL is what makes redirect-after-post work: the
 * browser ends up somewhere it can safely reload or bookmark, and a refresh
 * cannot send the message twice.
 *
 * This is the only resolver in the project that implements `handleSubmission`.
 */
component singleton accessors="true" {

	property name="contactService" inject="ContactService@contact";
	property name="csrf"           inject="CsrfService@core";
	property name="settings"       inject="coldbox:moduleSettings:contact";
	property name="log"            inject="logbox:logger:{this}";

	/* -------------------------------------------------------------- reading */

	function resolveContent( required numeric siteId, required string path ){
		var base = basePath();

		if ( !len( base ) ) {
			return;
		}

		if ( arguments.path == base ) {
			return formResolution( arguments.siteId );
		}

		if ( arguments.path == base & "/" & thankYouSegment() ) {
			return thankYouResolution( arguments.siteId );
		}

		return;
	}

	/* ------------------------------------------------------------ submitting */

	/**
	 * Receive a posted form.
	 *
	 * @formData Submitted values as a plain struct. No event, no request: this
	 *           module still knows nothing about HTTP.
	 *
	 * @return A resolution — the thank-you redirect, or the form again with
	 *         errors — or null when this path is not ours.
	 */
	function handleSubmission(
		required numeric siteId,
		required string path,
		required struct formData
	){
		if ( arguments.path != basePath() ) {
			return;
		}

		var contactForm = resolveForm( arguments.siteId, arguments.formData.form ?: "" );

		if ( isNull( contactForm ) ) {
			return;
		}

		// A token proves the form came from a session that was actually served
		// this page. Without it, anything on the internet could post here.
		if ( !csrf.verify( arguments.formData.csrfToken ?: "" ) ) {
			return failed( contactForm, arguments.formData, [ "That form expired. Please try again." ] );
		}

		// A field a person never sees and never fills in. Cheap, and it stops
		// the bots that submit every input they find.
		if ( len( trim( arguments.formData[ honeypotField() ] ?: "" ) ) ) {
			log.warn( "Contact honeypot tripped on site [#arguments.siteId#]." );

			// Answer exactly as a success would, so a bot learns nothing about
			// why it failed.
			return { "redirectTo" : "/" & basePath() & "/" & thankYouSegment() };
		}

		var errors = contactService.validateSubmission( arguments.formData );

		if ( errors.len() ) {
			return failed( contactForm, arguments.formData, errors );
		}

		try {
			contactService.submit(
				form      = contactForm,
				values    = arguments.formData,
				ipAddress = senderAddress(),
				userAgent = cgi.http_user_agent ?: ""
			);
		} catch ( Contact.TooManySubmissions e ) {
			return failed( contactForm, arguments.formData, [ e.message ] );
		} catch ( Contact.InvalidSubmission e ) {
			return failed( contactForm, arguments.formData, [ e.message ] );
		} catch ( Contact.FormInactive e ) {
			return failed( contactForm, arguments.formData, [ e.message ] );
		}

		return { "redirectTo" : "/" & basePath() & "/" & thankYouSegment() };
	}

	/* ---------------------------------------------------------------- shapes */

	private function formResolution( required numeric siteId ){
		var contactForm = contactService.getDefaultForm( arguments.siteId );

		// No form configured: the site does not serve this URL at all, so Pages
		// gets its turn and an ordinary /contact page still works.
		if ( isNull( contactForm ) ) {
			return;
		}

		return {
			"view" : "contact-form",
			"args" : {
				"form"          : contactForm,
				"errors"        : [],
				"values"        : {},
				"csrfToken"     : csrf.getCurrentToken(),
				"honeypotField" : honeypotField(),
				"action"        : "/" & basePath()
			},
			"title"           : contactForm.getName(),
			"metaDescription" : "",
			"statusCode"      : 200
		};
	}

	private function thankYouResolution( required numeric siteId ){
		var contactForm = contactService.getDefaultForm( arguments.siteId );

		if ( isNull( contactForm ) ) {
			return;
		}

		return {
			"view"            : "contact-sent",
			"args"            : { "form" : contactForm, "message" : contactForm.getSuccessMessage() },
			"title"           : "Thank you",
			"metaDescription" : "",
			"statusCode"      : 200
		};
	}

	/**
	 * The form again, carrying what was typed and what was wrong with it.
	 */
	private function failed(
		required contact.models.ContactForm form,
		required struct values,
		required array errors
	){
		return {
			"view" : "contact-form",
			"args" : {
				"form"          : arguments.form,
				"errors"        : arguments.errors,
				"values"        : arguments.values,
				"csrfToken"     : csrf.getCurrentToken(),
				"honeypotField" : honeypotField(),
				"action"        : "/" & basePath()
			},
			"title"           : arguments.form.getName(),
			"metaDescription" : "",
			// The submission was refused, so this is not a successful request.
			"statusCode"      : 422
		};
	}

	/* --------------------------------------------------------------- helpers */

	private function resolveForm( required numeric siteId, required string slug ){
		if ( len( trim( arguments.slug ) ) ) {
			var named = contactService.getFormBySlug( arguments.siteId, arguments.slug );

			if ( !isNull( named ) ) {
				return named;
			}
		}

		return contactService.getDefaultForm( arguments.siteId );
	}

	/**
	 * The sender's address, preferring a proxy header when one is configured.
	 *
	 * `X-Forwarded-For` is trivially forged, so it is only consulted when the
	 * deployment says it sits behind a proxy that sets it.
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

	private string function basePath(){
		return reReplace( lCase( trim( settings.basePath ?: "contact" ) ), "^/+|/+$", "", "all" );
	}

	private string function thankYouSegment(){
		return reReplace( lCase( trim( settings.thankYouSegment ?: "thank-you" ) ), "^/+|/+$", "", "all" );
	}

	private string function honeypotField(){
		return settings.honeypotField ?: "website";
	}

}
