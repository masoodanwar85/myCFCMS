/**
 * Strips dangerous markup out of author-supplied content.
 *
 * Group 5 shipped with page content rendered unescaped, which made
 * `pages.update` a permission to run arbitrary script on a client's public
 * site. That is the usual CMS bargain, but it should be a decision an operator
 * makes deliberately for specific people — not something every editor gets by
 * default.
 *
 * So content is sanitised by default, and callers that know the author holds
 * `content.unfiltered` can opt out.
 *
 * The engine-specific call lives here alone. `getSafeHTML` is ColdFusion's
 * OWASP AntiSamy binding; moving to another engine means changing this file and
 * nothing else. The policy it sanitises against ships with the project — see
 * `resources/security/antisamy-cms.xml`.
 */
component singleton accessors="true" {

	property name="log"      inject="logbox:logger:{this}";
	property name="settings" inject="coldbox:moduleSettings:core";

	/**
	 * @html      Author-supplied markup.
	 * @unfiltered Skip sanitising, for an author trusted with raw HTML.
	 *
	 * @return The markup with script, event handlers and unsafe URLs removed.
	 */
	string function sanitize( string html = "", boolean unfiltered = false ){
		var content = arguments.html ?: "";

		if ( arguments.unfiltered || !len( trim( content ) ) ) {
			return content;
		}

		try {
			return getSafeHTML( content, policyPath() );
		} catch ( any e ) {
			// Failing open would publish exactly the markup we could not vet.
			// Escaping it renders the author's markup as visible text, which is
			// wrong but obvious, rather than dangerous and invisible.
			log.error( "Sanitising content failed, falling back to escaping: #e.message#" );
			return encodeForHTML( content );
		}
	}

	/**
	 * The AntiSamy policy to sanitise against.
	 *
	 * ColdFusion's bundled `antisamy-basic.xml` strips headings, tables,
	 * horizontal rules, underline and strikethrough — everything the rich text
	 * editor offers beyond bold and italic. Sanitising with it deleted authors'
	 * markup silently, so the CMS ships its own policy.
	 */
	string function policyPath(){
		return expandPath( settings.sanitizerPolicy ?: "/resources/security/antisamy-cms.xml" );
	}

	/**
	 * Would sanitising change this markup?
	 *
	 * Lets an admin screen warn an author that something was removed, instead of
	 * silently dropping part of their work.
	 */
	boolean function isSafe( string html = "" ){
		var content = arguments.html ?: "";

		if ( !len( trim( content ) ) ) {
			return true;
		}

		return compare( content, sanitize( content ) ) == 0;
	}

}
