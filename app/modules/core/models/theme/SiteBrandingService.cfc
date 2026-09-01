/**
 * The per-site half of a theme's appearance.
 *
 * A theme is code, deployed with the application and shared by every site that
 * selects it. What differs between two sites on the same theme is almost never
 * the stylesheet — it is a logo and a handful of tokens. Modelling that as
 * settings rather than as per-site stylesheets keeps the theme one artefact and
 * gives a client something they can change themselves.
 *
 * Values are emitted as CSS custom properties on `:root`, so a theme opts in by
 * writing `var( --brand-primary, ##0f2a4a )` and needs no knowledge of this
 * service. A site that has set nothing produces no declarations, and the
 * theme's own fallbacks stand.
 *
 * ## Why the logo is a URL and not a media id
 *
 * Core does not depend on feature modules — that is what the registry seams
 * exist to preserve — and Media is a module. Storing the URL the picker already
 * hands back keeps the dependency arrow pointing the right way, and lets an
 * operator paste an external address if they ever need to. The cost is that
 * deleting the media item leaves a broken reference rather than cascading, which
 * is visible immediately and repaired in one field.
 *
 * ## Untrusted by construction
 *
 * These values reach a `<style>` block, where a stray `}` ends the rule and
 * anything after it is new CSS. Every value is therefore validated against a
 * deliberately narrow pattern on the way in *and* re-checked on the way out —
 * a setting written before this validation existed, or by a future code path,
 * must not become a stylesheet.
 */
component singleton accessors="true" {

	property name="siteSettingsRepo" inject="SiteSettingsRepository@core";

	this.KEY_LOGO_URL   = "branding.logoUrl";
	this.KEY_PRIMARY    = "branding.colorPrimary";
	this.KEY_ACCENT     = "branding.colorAccent";
	this.KEY_FONT_HEAD  = "branding.fontHeading";
	this.KEY_FONT_BODY  = "branding.fontBody";

	/**
	 * A CSS colour we are willing to interpolate: a hex literal, nothing else.
	 * Named colours and `rgb()` are excluded not because they are dangerous but
	 * because allowing function syntax means allowing parentheses, and the
	 * pattern stops being obviously safe to read.
	 */
	variables.COLOR_PATTERN = "^##([0-9a-fA-F]{3}|[0-9a-fA-F]{4}|[0-9a-fA-F]{6}|[0-9a-fA-F]{8})$";

	/**
	 * A font stack: family names, quotes, commas, spaces. No semicolons, no
	 * braces, no parentheses — so no `url(`, and no way out of the declaration.
	 */
	variables.FONT_PATTERN = "^[a-zA-Z0-9 ,'""\-]{1,120}$";

	/* ---------------------------------------------------------------------
	 * Reading
	 * ------------------------------------------------------------------ */

	/**
	 * Everything a layout needs, in one call.
	 *
	 * @return { logoUrl, colorPrimary, colorAccent, fontHeading, fontBody, styles }
	 */
	struct function brandingFor( required numeric siteId ){
		var branding = {
			"logoUrl"      : logoUrlFor( arguments.siteId ),
			"colorPrimary" : validColor( raw( arguments.siteId, this.KEY_PRIMARY ) ),
			"colorAccent"  : validColor( raw( arguments.siteId, this.KEY_ACCENT ) ),
			"fontHeading"  : validFont( raw( arguments.siteId, this.KEY_FONT_HEAD ) ),
			"fontBody"     : validFont( raw( arguments.siteId, this.KEY_FONT_BODY ) )
		};

		branding[ "styles" ] = styleBlockFrom( branding );

		return branding;
	}

	/**
	 * The site's logo, or an empty string.
	 *
	 * Only a site-relative or absolute http(s) address is returned. A stored
	 * `javascript:` or `data:` value — which could only arrive by editing the
	 * database directly — is discarded rather than rendered into `src`.
	 */
	string function logoUrlFor( required numeric siteId ){
		var stored = raw( arguments.siteId, this.KEY_LOGO_URL );

		return isUsableUrl( stored ) ? stored : "";
	}

	/**
	 * The `<style>` body for a site, or an empty string when nothing is set.
	 *
	 * Returned without the surrounding tag: the layout decides where it goes,
	 * and a caller that wants the values individually should use `brandingFor`.
	 */
	string function styleBlockFor( required numeric siteId ){
		return brandingFor( arguments.siteId ).styles;
	}

	/* ---------------------------------------------------------------------
	 * Writing
	 * ------------------------------------------------------------------ */

	/**
	 * @throws Branding.InvalidColor when a colour is not a hex literal.
	 * @throws Branding.InvalidFont  when a font stack contains anything but names.
	 * @throws Branding.InvalidUrl   when the logo is not an http(s) or site-relative address.
	 */
	function save(
		required numeric siteId,
		string logoUrl     = "",
		string colorPrimary = "",
		string colorAccent  = "",
		string fontHeading  = "",
		string fontBody     = ""
	){
		var logo = trim( arguments.logoUrl );

		if ( len( logo ) && !isUsableUrl( logo ) ) {
			throw(
				type    = "Branding.InvalidUrl",
				message = "The logo address must start with / or with http:// or https://."
			);
		}

		siteSettingsRepo.put( arguments.siteId, this.KEY_LOGO_URL, logo );

		putColor( arguments.siteId, this.KEY_PRIMARY, arguments.colorPrimary, "primary colour" );
		putColor( arguments.siteId, this.KEY_ACCENT,  arguments.colorAccent,  "accent colour" );
		putFont(  arguments.siteId, this.KEY_FONT_HEAD, arguments.fontHeading, "heading font" );
		putFont(  arguments.siteId, this.KEY_FONT_BODY, arguments.fontBody,    "body font" );

		return this;
	}

	/* ---------------------------------------------------------------------
	 * Validation
	 * ------------------------------------------------------------------ */

	boolean function isValidColor( required string value ){
		return reFind( variables.COLOR_PATTERN, trim( arguments.value ) ) > 0;
	}

	boolean function isValidFont( required string value ){
		return reFind( variables.FONT_PATTERN, trim( arguments.value ) ) > 0;
	}

	/**
	 * A logo address we are willing to put in `src`.
	 *
	 * Site-relative, or an explicit http(s) URL. Anything else — a scheme-less
	 * `//host` that inherits the page's protocol, `javascript:`, `data:` — is
	 * rejected.
	 */
	boolean function isUsableUrl( required string value ){
		var url = trim( arguments.value );

		if ( !len( url ) || len( url ) > 500 ) {
			return false;
		}

		// The whole string is constrained, not just the prefix. Anchoring only
		// the start would accept `https://x" onerror="alert(1)` — a valid
		// prefix followed by an attribute break. Output encoding would still
		// contain that, but a validator that admits it is not a validator.
		if ( reFind( "[^A-Za-z0-9\-._~:/?##\[\]@!$&''()*+,;=%]", url ) ) {
			return false;
		}

		// A protocol-relative URL is excluded along with everything else that
		// is not one of the two shapes below.
		return reFindNoCase( "^/[^/]", url ) > 0
			|| reFindNoCase( "^https?://[a-z0-9]", url ) > 0;
	}

	/* ---------------------------------------------------------------------
	 * Helpers
	 * ------------------------------------------------------------------ */

	/**
	 * The custom properties, built only from values that still validate.
	 *
	 * Re-checking here rather than trusting the stored value is the point: this
	 * is the last gate before the string becomes CSS.
	 */
	private string function styleBlockFrom( required struct branding ){
		var declarations = [];

		if ( len( arguments.branding.colorPrimary ) ) {
			arrayAppend( declarations, "--brand-primary: " & arguments.branding.colorPrimary & ";" );
		}

		if ( len( arguments.branding.colorAccent ) ) {
			arrayAppend( declarations, "--brand-accent: " & arguments.branding.colorAccent & ";" );
		}

		if ( len( arguments.branding.fontHeading ) ) {
			arrayAppend( declarations, "--brand-font-heading: " & arguments.branding.fontHeading & ";" );
		}

		if ( len( arguments.branding.fontBody ) ) {
			arrayAppend( declarations, "--brand-font-body: " & arguments.branding.fontBody & ";" );
		}

		if ( !arrayLen( declarations ) ) {
			return "";
		}

		return ":root{" & arrayToList( declarations, "" ) & "}";
	}

	private string function raw( required numeric siteId, required string key ){
		return trim( siteSettingsRepo.getValue( arguments.siteId, arguments.key, "" ) );
	}

	private string function validColor( required string value ){
		return isValidColor( arguments.value ) ? trim( arguments.value ) : "";
	}

	private string function validFont( required string value ){
		return isValidFont( arguments.value ) ? trim( arguments.value ) : "";
	}

	private function putColor(
		required numeric siteId,
		required string key,
		required string value,
		required string label
	){
		var color = trim( arguments.value );

		if ( len( color ) && !isValidColor( color ) ) {
			throw(
				type    = "Branding.InvalidColor",
				message = "The #arguments.label# must be a hex value such as ##0f2a4a."
			);
		}

		siteSettingsRepo.put( arguments.siteId, arguments.key, color );

		return this;
	}

	private function putFont(
		required numeric siteId,
		required string key,
		required string value,
		required string label
	){
		var font = trim( arguments.value );

		if ( len( font ) && !isValidFont( font ) ) {
			throw(
				type    = "Branding.InvalidFont",
				message = "The #arguments.label# may contain only family names, quotes and commas."
			);
		}

		siteSettingsRepo.put( arguments.siteId, arguments.key, font );

		return this;
	}

}
