/**
 * `[form slug="registration"]` — one of the site's forms, in page content.
 *
 * The only way a form is published. There are no routes: a form belongs under
 * the copy that explains it, and a second address for the same thing is a
 * second thing to keep in step.
 *
 * Rendering goes through the site's theme when the theme supplies a `form`
 * view, and falls back to Core's own otherwise. That matters more here than it
 * did for the contact form: a theme cannot be expected to have a view for a
 * form that did not exist when the theme was written, so the fallback is the
 * normal case rather than the exception.
 */
component singleton accessors="true" {

	property name="formService"  inject="FormService@forms";
	property name="themeService" inject="ThemeService@core";
	property name="renderer"     inject="provider:coldbox:renderer";
	property name="csrf"         inject="CsrfService@core";
	property name="recaptcha"    inject="RecaptchaService@core";
	property name="resolver"     inject="FormContentResolver@forms";
	property name="settings"     inject="coldbox:moduleSettings:forms";
	property name="flash"        inject="coldbox:flash";
	property name="log"          inject="logbox:logger:{this}";

	this.TAG         = "form";
	this.DESCRIPTION = 'Embeds one of this site''s forms: [form slug="registration"]';

	string function render( struct attributes = {}, string body = "", struct context = {} ){
		var siteId = val( arguments.context.siteId ?: 0 );
		var slug   = trim( arguments.attributes.slug ?: "" );

		if ( !siteId || !len( slug ) ) {
			return "";
		}

		var built = formService.getFormBySlug( siteId, slug, true );

		if ( isNull( built ) ) {
			// Silence rather than an error in the page. A shortcode naming a
			// form that was renamed or switched off is an editor's problem, and
			// printing it tells visitors about the site's internals.
			log.warn( "Shortcode [form] on site [#siteId#] names no active form [#slug#]." );

			return "";
		}

		var outcome = takeFlash( built.getSlug() );

		if ( outcome.sent ?: false ) {
			return renderView( siteId, "form-sent", {
				"form"    : built,
				"message" : outcome.message ?: built.getSuccessMessage()
			} );
		}

		return renderView( siteId, "form", {
			"form"          : built,
			"fields"        : built.getFields(),
			"errors"        : outcome.errors ?: [],
			"values"        : outcome.values ?: {},
			"csrfToken"     : csrf.getCurrentToken(),
			"markerField"   : resolver.markerField(),
			"honeypotField" : settings.honeypotField ?: "website",
			// Posts back to the page it sits on, so the visitor never leaves the
			// content that explained the form.
			"action"        : "/" & ( arguments.context.path ?: "" ),
			"recaptchaSiteKey" : recaptcha.isConfigured( siteId ) ? recaptcha.getSiteKey( siteId ) : ""
		} );
	}

	/* --------------------------------------------------------------------- */

	/**
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
	 * The theme's view if it has one, Core's otherwise.
	 *
	 * A theme written before this module existed has no `form` view, and that
	 * must not mean a blank page — so Core ships one and a theme overrides it
	 * by supplying its own.
	 */
	private string function renderView(
		required numeric siteId,
		required string view,
		required struct args
	){
		try {
			var theme = themeService.getThemeForSite( arguments.siteId );

			if ( theme.hasView( arguments.view ) ) {
				return themeService.renderView( theme = theme, view = arguments.view, args = arguments.args );
			}

			// `renderer`, not `renderer.get()`: the `provider:` DSL already hands
			// back the Renderer itself. ThemeService does the same thing.
			return renderer.view(
				view   = "forms/" & arguments.view,
				module = "core",
				args   = arguments.args
			);
		} catch ( any e ) {
			log.error( "Shortcode [form] could not render [#arguments.view#]: #e.message#", e );

			return "";
		}
	}

}
