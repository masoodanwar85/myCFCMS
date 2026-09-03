/**
 * `[contact-form]` — a contact form embedded in page or post content.
 *
 *     [contact-form]
 *
 * ## Why this exists
 *
 * The site's enquiry form, placed in a page rather than only at `/contact`. An
 * author can drop it under the copy that explains it instead of linking away to
 * a bare URL.
 *
 * It takes no attributes. A site has one contact form; a form with its own
 * fields is a different thing and belongs to the Forms module, which has its
 * own `[form]` shortcode.
 *
 * ## Rendering
 *
 * Through the site's theme, not markup written here. `contact-form.cfm` and
 * `contact-sent.cfm` already exist in every theme and a client may have styled
 * them; an embedded form that looked different from the one at `/contact`
 * would be a bug in waiting. The theme is told it is `embedded` so it can drop
 * the page-level heading and wrapper — a form inside a page already has both.
 *
 * ## The round trip
 *
 * The form posts back to the page it sits on. `ContactContentResolver` claims
 * that POST when it carries a slug naming an active form for the site, and
 * answers with a redirect either way, leaving the outcome in flash. This reads
 * it back: `sent` renders the success message in place of the form, and errors
 * re-render the form with what the visitor typed.
 *
 * The flash is keyed by form slug, so two forms on one page do not show each
 * other's messages.
 */
component singleton accessors="true" {

	property name="contactService" inject="ContactService@contact";
	property name="themeService"   inject="ThemeService@core";
	property name="csrf"           inject="CsrfService@core";
	property name="recaptcha"      inject="RecaptchaService@core";
	property name="resolver"       inject="ContactContentResolver@contact";
	property name="settings"       inject="coldbox:moduleSettings:contact";
	property name="flash"          inject="coldbox:flash";
	property name="log"            inject="logbox:logger:{this}";

	this.TAG         = "contact-form";
	this.DESCRIPTION = "Embeds this site's contact form: [contact-form]";

	string function render( struct attributes = {}, string body = "", struct context = {} ){
		var siteId = val( arguments.context.siteId ?: 0 );

		if ( !siteId ) {
			return "";
		}

		// No `slug` attribute: a site has one contact form. A form with its
		// own fields is the Forms module's job, and `[form]` is how one of
		// those is embedded.
		var contactForm = contactService.getFormForSite( siteId );

		if ( isNull( contactForm ) ) {
			// Silence rather than an error message. A site with no contact form
			// yet, or one switched off, is a configuration matter; printing it
			// into a client's live page tells visitors about the site's
			// internals.
			return "";
		}

		var outcome = takeFlash( contactForm.getSlug() );

		if ( outcome.sent ?: false ) {
			return renderThroughTheme( siteId, "contact-sent", {
				"form"     : contactForm,
				"message"  : outcome.message ?: contactForm.getSuccessMessage(),
				"embedded" : true
			} );
		}

		return renderThroughTheme( siteId, "contact-form", {
			"form"          : contactForm,
			"errors"        : outcome.errors ?: [],
			"values"        : outcome.values ?: {},
			"csrfToken"     : csrf.getCurrentToken(),
			"honeypotField" : settings.honeypotField ?: "website",
			// Posts back to the page it sits on, so the visitor never leaves
			// the content that explained the form.
			"action"        : "/" & ( arguments.context.path ?: "" ),
			// Public key only, and empty unless both keys are set, so a theme
			// never renders a widget this site could not verify.
			"recaptchaSiteKey" : recaptcha.isConfigured( siteId ) ? recaptcha.getSiteKey( siteId ) : "",
			"embedded"      : true
		} );
	}

	/* --------------------------------------------------------------------- */

	/**
	 * The outcome of the submission that led to this render, if there was one.
	 *
	 * Read once and cleared: a success message that survived into the next page
	 * view would tell a visitor they had sent something they had not.
	 */
	private struct function takeFlash( required string slug ){
		var key = resolver.flashKey( arguments.slug );

		if ( !flash.exists( key ) ) {
			return {};
		}

		var state = flash.get( key, {} );

		flash.remove( key );

		return isStruct( state ) ? state : {};
	}

	/**
	 * @throws nothing — a theme missing the view renders as empty rather than
	 *         turning one bad shortcode into a 500 on a client's page.
	 */
	private string function renderThroughTheme(
		required numeric siteId,
		required string view,
		required struct args
	){
		try {
			return themeService.renderView(
				theme = themeService.getThemeForSite( arguments.siteId ),
				view  = arguments.view,
				args  = arguments.args
			);
		} catch ( any e ) {
			log.error( "Shortcode [contact-form] could not render [#arguments.view#]: #e.message#", e );
			return "";
		}
	}

}
