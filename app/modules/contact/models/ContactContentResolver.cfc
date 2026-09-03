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
	property name="recaptcha"      inject="RecaptchaService@core";
	property name="settings"       inject="coldbox:moduleSettings:contact";
	property name="flash"          inject="coldbox:flash";
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
		// Two ways a submission arrives, and they end differently.
		//
		//   * `/contact` — this resolver owns the URL, so a validation failure
		//     can be answered by re-rendering the form in place.
		//   * anywhere else — a `[contact-form]` embedded in a page that Pages
		//     owns. This resolver cannot re-render that page, so both outcomes
		//     are answered with a redirect and the state is carried in flash.
		//
		// The difference is forced by who owns the URL, not chosen.
		var embedded = arguments.path != basePath();

		var contactForm = contactService.getFormForSite( arguments.siteId );

		if ( isNull( contactForm ) ) {
			return;
		}

		// On someone else's URL the posted marker is the only thing saying this
		// POST is ours at all, so it has to match this site's form. It is no
		// longer a *lookup* — a site has one contact form, so the slug can only
		// confirm or deny, never select. That closes the hole where editing the
		// hidden field routed a message to a different recipient.
		if ( embedded && ( arguments.formData.form ?: "" ) != contactForm.getSlug() ) {
			return;
		}

		// A token proves the form came from a session that was actually served
		// this page. Without it, anything on the internet could post here.
		if ( !csrf.verify( arguments.formData.csrfToken ?: "" ) ) {
			return refuse( embedded, arguments.path, contactForm, arguments.formData, [ "That form expired. Please try again." ] );
		}

		// A field a person never sees and never fills in. Cheap, and it stops
		// the bots that submit every input they find.
		if ( len( trim( arguments.formData[ honeypotField() ] ?: "" ) ) ) {
			log.warn( "Contact honeypot tripped on site [#arguments.siteId#]." );

			// Answer exactly as a success would, so a bot learns nothing about
			// why it failed.
			return { "redirectTo" : "/" & basePath() & "/" & thankYouSegment() };
		}

		// After the honeypot on purpose: a bot caught by the free check should
		// not cost a round trip to Google. Before validation and before
		// anything is stored, because an unverified submission must not reach
		// the database or the notification mail at all.
		var challenge = recaptcha.verify(
			siteId        = arguments.siteId,
			token         = arguments.formData[ "g-recaptcha-response" ] ?: "",
			remoteAddress = senderAddress()
		);

		if ( !challenge.success ) {
			return refuse( embedded, arguments.path, contactForm, arguments.formData, [ challenge.error ] );
		}

		var errors = contactService.validateSubmission( arguments.formData );

		if ( errors.len() ) {
			return refuse( embedded, arguments.path, contactForm, arguments.formData, errors );
		}

		try {
			contactService.submit(
				form      = contactForm,
				values    = arguments.formData,
				ipAddress = senderAddress(),
				userAgent = cgi.http_user_agent ?: ""
			);
		} catch ( Contact.TooManySubmissions e ) {
			return refuse( embedded, arguments.path, contactForm, arguments.formData, [ e.message ] );
		} catch ( Contact.InvalidSubmission e ) {
			return refuse( embedded, arguments.path, contactForm, arguments.formData, [ e.message ] );
		} catch ( Contact.FormInactive e ) {
			return refuse( embedded, arguments.path, contactForm, arguments.formData, [ e.message ] );
		}

		return succeed( embedded, arguments.path, contactForm );
	}

	/* ------------------------------------------------------------- outcomes */

	/**
	 * Where a visitor goes after their message is accepted.
	 *
	 * Three answers, in order of precedence:
	 *
	 *   1. The form's own `thankYouPath`, when one is configured. This is what
	 *      advertising conversion tracking needs — Google Ads and GA4 fire on a
	 *      URL being loaded, and a message swapped in by the server produces no
	 *      such URL.
	 *   2. Back to the page the form was embedded in, with the success message
	 *      in flash for the shortcode to render in place of the form.
	 *   3. `/contact/thank-you`, unchanged, for the standalone form.
	 */
	private struct function succeed(
		required boolean embedded,
		required string path,
		required contact.models.ContactForm form
	){
		var configured = arguments.form.getThankYouPath() ?: "";

		if ( len( configured ) ) {
			return { "redirectTo" : configured };
		}

		if ( !arguments.embedded ) {
			return { "redirectTo" : "/" & basePath() & "/" & thankYouSegment() };
		}

		flashFor( arguments.form, {
			"sent"    : true,
			"message" : arguments.form.getSuccessMessage()
		} );

		return { "redirectTo" : "/" & arguments.path };
	}

	/**
	 * Where a visitor goes when their message is refused.
	 *
	 * On `/contact` this re-renders the form with its errors and a 422, as it
	 * always has. Embedded, that is not available — the page belongs to another
	 * module — so the errors and what was typed go into flash and the visitor is
	 * sent back to the same URL. That also means a refusal cannot be re-posted
	 * by refreshing, which the 422 path still allows.
	 */
	private struct function refuse(
		required boolean embedded,
		required string path,
		required contact.models.ContactForm form,
		required struct values,
		required array errors
	){
		if ( !arguments.embedded ) {
			return failed( arguments.form, arguments.values, arguments.errors );
		}

		flashFor( arguments.form, {
			"sent"   : false,
			"errors" : arguments.errors,
			// Only the fields the form actually has. Flashing the whole post
			// would put the CSRF token and the reCAPTCHA response into the
			// session and back into the next page.
			"values" : {
				"name"    : arguments.values.name    ?: "",
				"email"   : arguments.values.email   ?: "",
				"subject" : arguments.values.subject ?: "",
				"message" : arguments.values.message ?: ""
			}
		} );

		return { "redirectTo" : "/" & arguments.path };
	}

	/**
	 * Keyed by the form's slug, so two forms on one page — or the same
	 * shortcode twice — cannot show each other's message.
	 */
	private function flashFor( required contact.models.ContactForm form, required struct state ){
		flash.put( flashKey( arguments.form.getSlug() ), arguments.state );

		return this;
	}

	string function flashKey( required string slug ){
		return "contactForm_" & arguments.slug;
	}

	/* ---------------------------------------------------------------- shapes */

	private function formResolution( required numeric siteId ){
		var contactForm = contactService.getFormForSite( arguments.siteId );
		var siteIdOf    = arguments.siteId;

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
				"action"        : "/" & basePath(),
				// Public key only, and empty unless *both* keys are set — so a
				// theme never renders a widget this site cannot verify.
				"recaptchaSiteKey" : siteKeyFor( siteIdOf )
			},
			"title"           : contactForm.getName(),
			"metaDescription" : "",
			"statusCode"      : 200
		};
	}

	private function thankYouResolution( required numeric siteId ){
		var contactForm = contactService.getFormForSite( arguments.siteId );

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
		var siteIdOf = arguments.form.getSiteId();

		return {
			"view" : "contact-form",
			"args" : {
				"form"          : arguments.form,
				"errors"        : arguments.errors,
				"values"        : arguments.values,
				"csrfToken"     : csrf.getCurrentToken(),
				"honeypotField" : honeypotField(),
				"action"        : "/" & basePath(),
				// Public key only, and empty unless *both* keys are set — so a
				// theme never renders a widget this site cannot verify.
				"recaptchaSiteKey" : siteKeyFor( siteIdOf )
			},
			"title"           : arguments.form.getName(),
			"metaDescription" : "",
			// The submission was refused, so this is not a successful request.
			"statusCode"      : 422
		};
	}

	/* --------------------------------------------------------------- helpers */

	/**
	 * The sender's address, preferring a proxy header when one is configured.
	 *
	 * `X-Forwarded-For` is trivially forged, so it is only consulted when the
	 * deployment says it sits behind a proxy that sets it.
	 */
	/**
	 * The site key, or an empty string when reCAPTCHA is not fully configured.
	 *
	 * Going through `isConfigured()` rather than reading the key directly is
	 * what stops a site with a site key and no secret from rendering a widget
	 * that `verify()` would then wave through.
	 */
	private string function siteKeyFor( required numeric siteId ){
		return recaptcha.isConfigured( arguments.siteId ) ? recaptcha.getSiteKey( arguments.siteId ) : "";
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
		return reReplace( lCase( trim( settings.basePath ?: "contact" ) ), "^/+|/+$", "", "all" );
	}

	private string function thankYouSegment(){
		return reReplace( lCase( trim( settings.thankYouSegment ?: "thank-you" ) ), "^/+|/+$", "", "all" );
	}

	private string function honeypotField(){
		return settings.honeypotField ?: "website";
	}

}
