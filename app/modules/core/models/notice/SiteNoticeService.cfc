/**
 * A first-visit notice on every public page of a site.
 *
 * Campaign copy — a discount, a closing date, a call to action — is not a
 * design decision, so it does not live in a theme. It is a handful of strings
 * in `site_settings`, the same place analytics and branding keep theirs, and
 * this service is the only thing that reads and writes them.
 *
 * ## Why this is not a textarea of markup
 *
 * The obvious field is a box that holds HTML. That field would be arbitrary
 * markup and script on every page, saved by anyone with `site.settings.manage`.
 * Heading, body and a URL are values. They can be validated, they cannot close
 * a tag, and the dialog is generated here so turning the notice off is a
 * setting rather than a theme edit.
 *
 * Validated on the way in **and** again on read, because a row can reach
 * `site_settings` from a migration, a seed or a direct `UPDATE`.
 *
 * ## First visit is a browser fact
 *
 * The server emits the dialog when the notice is active. Whether this visitor
 * has already seen it is remembered in `localStorage`, keyed per site and
 * expiry, so a new campaign can appear again and an old one cannot.
 */
component singleton accessors="true" {

	property name="siteSettingsRepo" inject="SiteSettingsRepository@core";

	this.KEY_ENABLED    = "notice.enabled";
	this.KEY_HEADING    = "notice.heading";
	this.KEY_BODY       = "notice.body";
	this.KEY_CTA_URL    = "notice.ctaUrl";
	this.KEY_CTA_LABEL  = "notice.ctaLabel";
	this.KEY_EXPIRES_AT = "notice.expiresAt";

	variables.MAX_HEADING   = 80;
	variables.MAX_BODY      = 600;
	variables.MAX_CTA_LABEL = 40;
	variables.DATE_PATTERN  = "^[0-9]{4}-[0-9]{2}-[0-9]{2}$";

	/* ---------------------------------------------------------------- read */

	/**
	 * Everything a layout needs, in one call.
	 *
	 * `active` is false when the notice is off, empty, expired, or carrying a
	 * value that would not pass validation today — so a theme can emit nothing
	 * rather than a broken dialog.
	 */
	struct function noticeFor( required numeric siteId ){
		var heading   = clipped( raw( arguments.siteId, this.KEY_HEADING ), variables.MAX_HEADING );
		var body      = clipped( raw( arguments.siteId, this.KEY_BODY ), variables.MAX_BODY );
		var ctaUrl    = usableUrl( raw( arguments.siteId, this.KEY_CTA_URL ) );
		var ctaLabel  = clipped( raw( arguments.siteId, this.KEY_CTA_LABEL ), variables.MAX_CTA_LABEL );
		var expiresAt = validDate( raw( arguments.siteId, this.KEY_EXPIRES_AT ) );

		var active = isEnabled( arguments.siteId )
			&& len( heading )
			&& len( body )
			&& !isExpired( expiresAt );

		return {
			"active"     : active,
			"heading"    : heading,
			"body"       : body,
			"ctaUrl"     : ctaUrl,
			"ctaLabel"   : ctaLabel,
			"expiresAt"  : expiresAt,
			"storageKey" : storageKeyFor( arguments.siteId, expiresAt )
		};
	}

	/**
	 * Stored values for the settings form, including an inactive notice.
	 *
	 * Distinct from `noticeFor` because the admin has to show what was saved
	 * even when the public site is correctly emitting nothing.
	 */
	struct function settingsFor( required numeric siteId ){
		return {
			"enabled"    : isEnabled( arguments.siteId ),
			"heading"    : raw( arguments.siteId, this.KEY_HEADING ),
			"body"       : raw( arguments.siteId, this.KEY_BODY ),
			"ctaUrl"     : raw( arguments.siteId, this.KEY_CTA_URL ),
			"ctaLabel"   : raw( arguments.siteId, this.KEY_CTA_LABEL ),
			"expiresAt"  : raw( arguments.siteId, this.KEY_EXPIRES_AT )
		};
	}

	boolean function isEnabled( required numeric siteId ){
		var stored = trim( siteSettingsRepo.getValue( arguments.siteId, this.KEY_ENABLED, "" ) );

		return isBoolean( stored ) && stored;
	}

	/* --------------------------------------------------------------- write */

	/**
	 * @throws Notice.InvalidUrl  when the CTA is not an http(s) or site-relative address.
	 * @throws Notice.InvalidDate when the expiry is not a calendar date.
	 * @throws Notice.InvalidInput when a field is longer than it is allowed to be.
	 */
	function save(
		required numeric siteId,
		boolean enabled   = false,
		string heading    = "",
		string body       = "",
		string ctaUrl     = "",
		string ctaLabel   = "",
		string expiresAt  = ""
	){
		var headingValue  = trim( arguments.heading );
		var bodyValue     = trim( arguments.body );
		var ctaUrlValue   = trim( arguments.ctaUrl );
		var ctaLabelValue = trim( arguments.ctaLabel );
		var expiresValue  = trim( arguments.expiresAt );

		if ( len( headingValue ) > variables.MAX_HEADING ) {
			throw(
				type    = "Notice.InvalidInput",
				message = "The heading must be #variables.MAX_HEADING# characters or fewer."
			);
		}

		if ( len( bodyValue ) > variables.MAX_BODY ) {
			throw(
				type    = "Notice.InvalidInput",
				message = "The message must be #variables.MAX_BODY# characters or fewer."
			);
		}

		if ( len( ctaLabelValue ) > variables.MAX_CTA_LABEL ) {
			throw(
				type    = "Notice.InvalidInput",
				message = "The button label must be #variables.MAX_CTA_LABEL# characters or fewer."
			);
		}

		if ( len( ctaUrlValue ) && !isUsableUrl( ctaUrlValue ) ) {
			throw(
				type    = "Notice.InvalidUrl",
				message = "The button address must start with / or with http:// or https://."
			);
		}

		if ( len( expiresValue ) && !isCalendarDay( expiresValue ) ) {
			throw(
				type    = "Notice.InvalidDate",
				message = "The end date must be a calendar day such as 2026-10-31."
			);
		}

		siteSettingsRepo.put( arguments.siteId, this.KEY_ENABLED, arguments.enabled ? "true" : "false" );
		siteSettingsRepo.put( arguments.siteId, this.KEY_HEADING, headingValue );
		siteSettingsRepo.put( arguments.siteId, this.KEY_BODY, bodyValue );
		siteSettingsRepo.put( arguments.siteId, this.KEY_CTA_URL, ctaUrlValue );
		siteSettingsRepo.put( arguments.siteId, this.KEY_CTA_LABEL, ctaLabelValue );
		siteSettingsRepo.put( arguments.siteId, this.KEY_EXPIRES_AT, expiresValue );

		return this;
	}

	/* ------------------------------------------------------------ checking */

	boolean function isUsableUrl( required string value ){
		var url = trim( arguments.value );

		if ( !len( url ) || len( url ) > 500 ) {
			return false;
		}

		// The whole string is constrained, not just the prefix. Anchoring only
		// the start would accept `https://x" onerror="alert(1)` — a valid
		// prefix followed by an attribute break.
		if ( reFind( "[^A-Za-z0-9\-._~:/?##\[\]@!$&''()*+,;=%]", url ) ) {
			return false;
		}

		return reFindNoCase( "^/[^/]", url ) > 0
			|| reFindNoCase( "^https?://[a-z0-9]", url ) > 0;
	}

	boolean function isCalendarDay( required string value ){
		var candidate = trim( arguments.value );

		if ( reFind( variables.DATE_PATTERN, candidate ) == 0 ) {
			return false;
		}

		return isDate( candidate );
	}

	boolean function isExpired( required string expiresAt ){
		if ( !len( arguments.expiresAt ) ) {
			return false;
		}

		if ( !isCalendarDay( arguments.expiresAt ) ) {
			return true;
		}

		// Date-only comparison, so the notice runs through the whole of the
		// named day rather than stopping at midnight on it.
		return dateCompare( now(), parseDateTime( arguments.expiresAt ), "d" ) > 0;
	}

	/* ------------------------------------------------------------ helpers */

	private string function raw( required numeric siteId, required string key ){
		return trim( siteSettingsRepo.getValue( arguments.siteId, arguments.key, "" ) );
	}

	private string function clipped( required string value, required numeric maxLen ){
		var text = trim( arguments.value );

		if ( len( text ) > arguments.maxLen ) {
			return "";
		}

		return text;
	}

	private string function usableUrl( required string value ){
		return isUsableUrl( arguments.value ) ? trim( arguments.value ) : "";
	}

	private string function validDate( required string value ){
		return isCalendarDay( arguments.value ) ? trim( arguments.value ) : "";
	}

	private string function storageKeyFor( required numeric siteId, required string expiresAt ){
		var stamp = reReplace( arguments.expiresAt, "[^0-9]", "", "all" );

		if ( !len( stamp ) ) {
			stamp = "none";
		}

		return "cms-notice-" & arguments.siteId & "-" & stamp;
	}

}
