/**
 * The facts about a practice that a theme prints but does not own.
 *
 * A phone number, an address, the hours, the ABN, how fees are charged. Every
 * theme wants some of them and a client changes them without wanting a
 * deployment, so they are per-site settings — the same argument that put the
 * logo and brand colours in `SiteBrandingService`, applied to words instead of
 * to appearance.
 *
 * ## Why not page content
 *
 * Because each of these appears in four or five places at once. The phone
 * number in the probate theme is in the top bar, the hero, the contact block,
 * the closing call to action and the footer; as page content it would be five
 * copies that drift apart, and changing an address would mean finding all of
 * them. One setting, read wherever it is needed.
 *
 * ## Why every field is optional
 *
 * A theme has to render before a client has filled anything in. Everything
 * here returns an empty string when unset, and a theme is expected to drop the
 * element rather than print an empty label — which is why `has()` exists.
 *
 * ## Trust
 *
 * Most of these are printed as text and escaped at the point of output, so
 * they carry no more risk than a page title. Two are different: `phone` and
 * `email` end up inside `tel:` and `mailto:` hrefs, where a `javascript:`
 * value would be a link that runs. Those two are validated on the way in
 * **and** re-checked on the way out, for the same reason the branding service
 * does it — a row can reach `site_settings` from a migration, a seed or a
 * direct UPDATE, and the read path does not get to assume otherwise.
 */
component singleton accessors="true" {

	property name="siteSettingsRepo" inject="SiteSettingsRepository@core";

	/**
	 * The fields, in the order the settings form shows them.
	 *
	 * A list rather than a property each, because every one of them is handled
	 * identically — read, trim, store, print — and eleven near-identical
	 * methods would be eleven places to forget one. The settings screen builds
	 * its form from this too, so a new field is one entry here.
	 *
	 * `kind` picks the validation and the form control:
	 *   text  — a single line, escaped at output
	 *   lines — free text over several lines, escaped at output
	 *   phone — reaches a `tel:` href, so it is constrained
	 *   email — reaches a `mailto:` href, so it is constrained
	 *   url   — reaches an `href`, so only http(s) is accepted
	 *
	 * `group` is how the settings screen breaks the form up; it means nothing
	 * to a theme, which asks for fields by name.
	 */
	variables.FIELDS = [
		{
			key   : "trustLine",
			kind  : "text",
			group : "contact",
			label : "Trust line",
			hint  : "A short line of reassurance across the top bar, e.g. ""Acting for executors since 1994""."
		},
		{
			key   : "phone",
			kind  : "phone",
			group : "contact",
			label : "Phone",
			hint  : "Digits, spaces and + ( ) - only. Used as a click-to-call link."
		},
		{
			key   : "email",
			kind  : "email",
			group : "contact",
			label : "Email",
			hint  : "The address enquiries should reach."
		},
		{
			key   : "address",
			kind  : "lines",
			group : "contact",
			label : "Office address",
			hint  : "One line, or several. Printed as written."
		},
		{
			key   : "legalEntity",
			kind  : "text",
			group : "contact",
			label : "Legal entity name",
			hint  : "The name in the footer copyright line, if it differs from the site name."
		},
		{
			key   : "abn",
			kind  : "text",
			group : "contact",
			label : "ABN",
			hint  : "Printed in the footer beside the legal entity name."
		},

		/*
		 * Social profiles.
		 *
		 * One field each rather than a repeater, because the set is small,
		 * stable and known: a theme draws a named icon per network, and it can
		 * only do that if it knows which network a URL belongs to. A generic
		 * list of links would arrive without that, and the icon would have to
		 * be guessed from the hostname.
		 *
		 * `order` is the order they are rendered in, which is the order they
		 * appear here.
		 */
		{
			key   : "facebook",
			kind  : "url",
			group : "social",
			label : "Facebook",
			hint  : "The full address of your page, e.g. https://www.facebook.com/yourfirm"
		},
		{
			key   : "instagram",
			kind  : "url",
			group : "social",
			label : "Instagram",
			hint  : "e.g. https://www.instagram.com/yourfirm"
		},
		{
			key   : "linkedin",
			kind  : "url",
			group : "social",
			label : "LinkedIn",
			hint  : "e.g. https://www.linkedin.com/company/yourfirm"
		},
		{
			key   : "x",
			kind  : "url",
			group : "social",
			label : "X",
			hint  : "Formerly Twitter, e.g. https://x.com/yourfirm"
		},
		{
			key   : "tiktok",
			kind  : "url",
			group : "social",
			label : "TikTok",
			hint  : "e.g. https://www.tiktok.com/@yourfirm"
		},
		{
			key   : "youtube",
			kind  : "url",
			group : "social",
			label : "YouTube",
			hint  : "e.g. https://www.youtube.com/@yourfirm"
		},
		{
			key   : "whatsapp",
			kind  : "url",
			group : "social",
			label : "WhatsApp",
			hint  : "A wa.me link rather than a bare number, e.g. https://wa.me/61400000000"
		}
	];

	variables.KEY_PREFIX = "firm.";

	/**
	 * Digits and the punctuation a printed number uses. No letters, so no
	 * scheme can be smuggled into the `tel:` href this ends up in.
	 */
	variables.PHONE_PATTERN = "^[0-9 +().\-]{3,40}$";

	// Deliberately narrower than the RFC allows. An address this rejects can
	// still be typed into the contact form; this one becomes a `mailto:` link
	// in a page served to everybody.
	variables.EMAIL_PATTERN = "^[A-Za-z0-9._%+\-]{1,64}@[A-Za-z0-9.\-]{1,190}\.[A-Za-z]{2,24}$";

	/**
	 * A social profile address we are willing to put in an `href`.
	 *
	 * `http(s)` only, and the **whole** string is constrained rather than just
	 * the prefix — anchoring only the start would accept
	 * `https://x" onclick="alert(1)`, a valid prefix followed by an attribute
	 * break. Output encoding would still contain that, but a validator that
	 * admits it is not a validator. The same reasoning as the logo address in
	 * `SiteBrandingService`, minus the site-relative case: a social profile is
	 * on somebody else's domain by definition.
	 */
	variables.URL_PATTERN = "^https?://[A-Za-z0-9][A-Za-z0-9\-._~:/?##\[\]@!$&''()*+,;=%]{2,490}$";

	variables.MAX_TEXT  = 200;
	variables.MAX_LINES = 600;

	/* ---------------------------------------------------------------------
	 * Reading
	 * ------------------------------------------------------------------ */

	/**
	 * Everything a layout needs, in one call.
	 *
	 * Every key is present and every value is a string, so a theme can write
	 * `args.firm.phone` without testing for the key first. An unset or
	 * no-longer-valid value reads as an empty string.
	 */
	struct function firmFor( required numeric siteId ){
		var firm = {};

		for ( var field in variables.FIELDS ) {
			firm[ field.key ] = clean( field, raw( arguments.siteId, field.key ) );
		}

		return firm;
	}

	/**
	 * Whether a value is worth rendering.
	 *
	 * Exists so a theme writes `firm.has( "phone" )` rather than
	 * `len( trim( args.firm.phone ) )` in five places — and so "set but no
	 * longer valid" counts as absent, which is the behaviour a reader expects
	 * and not what a bare `len()` would give.
	 */
	boolean function hasValue( required struct firm, required string key ){
		return len( trim( arguments.firm[ arguments.key ] ?: "" ) ) > 0;
	}

	/**
	 * The social profiles this site has set, in the order a theme should draw
	 * them.
	 *
	 * Only the ones with a usable address, so a theme loops the result and
	 * draws nothing when it is empty — rather than testing seven keys and
	 * deciding for itself whether a row of icons is worth having.
	 *
	 * The `key` comes back so the theme can pick the right icon. That is the
	 * whole reason these are seven named fields and not a free list of links:
	 * a generic list would arrive with no way to tell Instagram from LinkedIn
	 * except by guessing at the hostname.
	 *
	 * @return [ { key, label, url } ]
	 */
	array function socialsFor( required numeric siteId ){
		var found = [];

		for ( var field in variables.FIELDS ) {
			if ( ( field.group ?: "" ) != "social" ) {
				continue;
			}

			var url = clean( field, raw( arguments.siteId, field.key ) );

			if ( len( url ) ) {
				found.append( { "key" : field.key, "label" : field.label, "url" : url } );
			}
		}

		return found;
	}

	/**
	 * What the settings form shows: the field definitions, with the stored
	 * value attached. The screen renders this rather than knowing the fields,
	 * so adding one is an entry in `FIELDS` and nothing else.
	 */
	array function settingsFor( required numeric siteId ){
		var rows = [];

		for ( var field in variables.FIELDS ) {
			var row = structCopy( field );

			// The stored value, not the cleaned one. A number that no longer
			// validates must still appear in the form — blanking the field is
			// how somebody loses it without being told.
			row.value = raw( arguments.siteId, field.key );
			row.valid = !len( row.value ) || isValidFor( field, row.value );

			rows.append( row );
		}

		return rows;
	}

	array function getFields(){
		return variables.FIELDS;
	}

	/* ---------------------------------------------------------------------
	 * Writing
	 * ------------------------------------------------------------------ */

	/**
	 * Save whichever fields were submitted.
	 *
	 * Validates **everything before storing anything**, so a bad phone number
	 * does not leave the address saved and the rest discarded — a partially
	 * applied form is harder to notice than a refused one.
	 *
	 * A field absent from `values` is left as it was; a field present and
	 * empty is cleared. That distinction is what lets one screen save a subset
	 * without blanking the others.
	 *
	 * @throws Firm.InvalidPhone
	 * @throws Firm.InvalidEmail
	 * @throws Firm.TooLong
	 */
	function save( required numeric siteId, required struct values ){
		var pending = [];

		for ( var field in variables.FIELDS ) {
			if ( !structKeyExists( arguments.values, field.key ) ) {
				continue;
			}

			var value = trim( arguments.values[ field.key ] ?: "" );

			if ( len( value ) ) {
				assertValid( field, value );
			}

			pending.append( { key : field.key, value : value } );
		}

		for ( var change in pending ) {
			siteSettingsRepo.put( arguments.siteId, variables.KEY_PREFIX & change.key, change.value );
		}

		return this;
	}

	/* ---------------------------------------------------------------------
	 * Validation
	 * ------------------------------------------------------------------ */

	boolean function isValidPhone( required string value ){
		return reFind( variables.PHONE_PATTERN, trim( arguments.value ) ) > 0;
	}

	boolean function isValidEmail( required string value ){
		return reFind( variables.EMAIL_PATTERN, trim( arguments.value ) ) > 0;
	}

	boolean function isValidUrl( required string value ){
		return reFind( variables.URL_PATTERN, trim( arguments.value ) ) > 0;
	}

	/* ---------------------------------------------------------------------
	 * Helpers
	 * ------------------------------------------------------------------ */

	/**
	 * Whether a value is acceptable for a field.
	 *
	 * **Not** named `isValid`: that is a ColdFusion built-in, and an
	 * unqualified call from inside this component resolves to the BIF rather
	 * than to the method — which then tries to read the field struct as its
	 * `type` argument and fails with "complex object types cannot be
	 * converted to simple values".
	 */
	private boolean function isValidFor( required struct field, required string value ){
		var text = trim( arguments.value );

		switch ( arguments.field.kind ) {
			case "phone":
				return isValidPhone( text );
			case "email":
				return isValidEmail( text );
			case "url":
				return isValidUrl( text );
			case "lines":
				return len( text ) <= variables.MAX_LINES;
			default:
				return len( text ) <= variables.MAX_TEXT;
		}
	}

	private function assertValid( required struct field, required string value ){
		if ( isValidFor( arguments.field, arguments.value ) ) {
			return this;
		}

		switch ( arguments.field.kind ) {
			case "phone":
				throw(
					type    = "Firm.InvalidPhone",
					message = "The phone number may contain only digits, spaces and + ( ) - because it becomes a click-to-call link."
				);
			case "email":
				throw( type = "Firm.InvalidEmail", message = "That does not look like an email address." );
			case "url":
				throw(
					type    = "Firm.InvalidUrl",
					message = "#arguments.field.label# must be a full web address beginning http:// or https://."
				);
			default:
				var limit = arguments.field.kind == "lines" ? variables.MAX_LINES : variables.MAX_TEXT;

				throw(
					type    = "Firm.TooLong",
					message = "#arguments.field.label# is longer than the #limit# characters this field holds."
				);
		}
	}

	/**
	 * The last gate before a value is handed to a theme.
	 *
	 * A stored value that would not pass validation today is dropped rather
	 * than returned — see the note at the top about how a row can get into
	 * `site_settings` without going through `save()`.
	 */
	private string function clean( required struct field, required string value ){
		var text = trim( arguments.value );

		if ( !len( text ) ) {
			return "";
		}

		return isValidFor( arguments.field, text ) ? text : "";
	}

	private string function raw( required numeric siteId, required string key ){
		return trim( siteSettingsRepo.getValue( arguments.siteId, variables.KEY_PREFIX & arguments.key, "" ) );
	}

}
