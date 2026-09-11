/**
 * A site's Google measurement tag.
 *
 * ## Why this stores an ID and not the snippet
 *
 * Google's instructions say to paste a `<script>` block into every page, so the
 * obvious field is a textarea that holds it. That field would be arbitrary
 * JavaScript on every page of the site, saved by anyone with
 * `site.settings.manage` and executed in every visitor's browser — a permission
 * meant for "change the site's configuration", not "run code on the public
 * site".
 *
 * An ID is a value, not a program. It can be validated, it cannot be pasted
 * twice — which is Google's own first warning — and the snippet is generated
 * here, so when Google changes it there is one place to change rather than
 * every site's settings row.
 *
 * ## Two different products
 *
 * Google calls both of these a "tag" and the difference is only the prefix:
 *
 *   `G-XXXXXXXXXX`    the Google tag, gtag.js — GA4. A script in the head.
 *   `GTM-XXXXXXX`     a Tag Manager container. A script in the head *and* a
 *                     `<noscript>` iframe immediately after `<body>`.
 *
 * Both are accepted and told apart by their prefix, because somebody reading
 * "add Google Tag Manager" may well paste either.
 *
 * `UA-` is deliberately refused: Universal Analytics stopped processing data in
 * 2023, and silently accepting one would mean a site that looks measured and is
 * not.
 */
component singleton accessors="true" {

	property name="siteSettingsRepo" inject="SiteSettingsRepository@core";

	this.KEY_TAG_ID = "analytics.googleTagId";

	/**
	 * Narrow on purpose. The value is interpolated into a script and a URL, so
	 * the pattern is the whole defence — anything outside these shapes is not a
	 * measurement ID and has no business in either.
	 */
	variables.GA4_PATTERN = "^G-[A-Z0-9]{4,20}$";
	variables.GTM_PATTERN = "^GTM-[A-Z0-9]{4,20}$";
	variables.UA_PATTERN  = "^UA-[0-9]{4,12}-[0-9]{1,4}$";

	/* ---------------------------------------------------------------- read */

	/**
	 * The site's tag id, or an empty string.
	 *
	 * Re-validated on the way out, not merely on the way in. A row can reach
	 * `site_settings` from a migration, a seed or a direct `UPDATE`, and this is
	 * the last gate before the value becomes a script tag.
	 */
	string function tagIdFor( required numeric siteId ){
		var stored = ucase( trim( siteSettingsRepo.getValue( arguments.siteId, this.KEY_TAG_ID, "" ) ) );

		return isValidTagId( stored ) ? stored : "";
	}

	boolean function isConfigured( required numeric siteId ){
		return len( tagIdFor( arguments.siteId ) ) > 0;
	}

	/**
	 * Everything a layout needs, in one call.
	 *
	 * @return { tagId, kind, head, body }
	 *         `kind` is "gtag", "gtm" or "" — `head` and `body` are ready to
	 *         emit, and empty when nothing is configured.
	 */
	struct function analyticsFor( required numeric siteId ){
		var tagId = tagIdFor( arguments.siteId );

		if ( !len( tagId ) ) {
			return { "tagId" : "", "kind" : "", "head" : "", "body" : "" };
		}

		var kind = isGtm( tagId ) ? "gtm" : "gtag";

		return {
			"tagId" : tagId,
			"kind"  : kind,
			"head"  : kind == "gtm" ? gtmHead( tagId ) : gtagHead( tagId ),
			"body"  : kind == "gtm" ? gtmBody( tagId ) : ""
		};
	}

	/* --------------------------------------------------------------- write */

	/**
	 * @throws Analytics.InvalidTagId when the value is not a usable id.
	 */
	function save( required numeric siteId, required string tagId ){
		var candidate = ucase( trim( arguments.tagId ) );

		if ( !len( candidate ) ) {
			siteSettingsRepo.put( arguments.siteId, this.KEY_TAG_ID, "" );

			return this;
		}

		if ( reFind( variables.UA_PATTERN, candidate ) ) {
			throw(
				type    = "Analytics.InvalidTagId",
				message = "[#arguments.tagId#] is a Universal Analytics id. Those stopped collecting data in 2023 — "
					& "use the GA4 measurement id from the same property, which starts with G-."
			);
		}

		if ( !isValidTagId( candidate ) ) {
			throw(
				type    = "Analytics.InvalidTagId",
				message = "[#arguments.tagId#] is not a Google tag id. Expected something like G-XXXXXXXXXX "
					& "for a Google tag, or GTM-XXXXXXX for a Tag Manager container.",
				detail  = "Paste only the id, not the whole script Google showed you."
			);
		}

		siteSettingsRepo.put( arguments.siteId, this.KEY_TAG_ID, candidate );

		return this;
	}

	/* ------------------------------------------------------------ checking */

	boolean function isValidTagId( required string tagId ){
		var candidate = ucase( trim( arguments.tagId ) );

		return reFind( variables.GA4_PATTERN, candidate ) > 0
			|| reFind( variables.GTM_PATTERN, candidate ) > 0;
	}

	boolean function isGtm( required string tagId ){
		return reFind( variables.GTM_PATTERN, ucase( trim( arguments.tagId ) ) ) > 0;
	}

	/* ------------------------------------------------------------ snippets */

	/**
	 * The id is already known to match `^G-[A-Z0-9]{4,20}$`, so there is
	 * nothing in it that can close a string or a tag. Written as one line
	 * rather than the indented block Google publishes, because whitespace in a
	 * head script is bytes on every page view and changes nothing.
	 */
	private string function gtagHead( required string tagId ){
		return '<script async src="https://www.googletagmanager.com/gtag/js?id=' & arguments.tagId & '"></script>'
			& '<script>window.dataLayer=window.dataLayer||[];function gtag(){dataLayer.push(arguments);}'
			& "gtag('js',new Date());gtag('config','" & arguments.tagId & "');</script>";
	}

	private string function gtmHead( required string tagId ){
		return "<script>(function(w,d,s,l,i){w[l]=w[l]||[];w[l].push({'gtm.start':new Date().getTime(),event:'gtm.js'});"
			& "var f=d.getElementsByTagName(s)[0],j=d.createElement(s),dl=l!='dataLayer'?'&l='+l:'';"
			& "j.async=true;j.src='https://www.googletagmanager.com/gtm.js?id='+i+dl;"
			& "f.parentNode.insertBefore(j,f);})(window,document,'script','dataLayer','" & arguments.tagId & "');</script>";
	}

	/**
	 * Tag Manager's fallback for a visitor with JavaScript disabled. Google
	 * places it immediately after `<body>`; a theme that does not emit it loses
	 * only those visitors, which is why the head half is not conditional on it.
	 */
	private string function gtmBody( required string tagId ){
		return '<noscript><iframe src="https://www.googletagmanager.com/ns.html?id=' & arguments.tagId & '"'
			& ' height="0" width="0" style="display:none;visibility:hidden"></iframe></noscript>';
	}

}
