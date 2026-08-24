/**
 * The handful of shortcodes Core itself answers for.
 *
 * Deliberately small. Core owns nothing a visitor reads, so the only things it
 * can usefully offer are facts about the site and the date — the sort of thing
 * that would otherwise go stale in a footer the day the year turned over.
 *
 * One component answers for several tags, dispatching on `context.tag`. Three
 * near-identical files would be worse.
 */
component singleton accessors="true" {

	property name="siteRepo" inject="SiteRepository@core";
	property name="seo"      inject="SeoService@core";

	this.TAGS = [
		{ tag : "year",      description : "The current year, e.g. 2026. For a footer that should not go stale." },
		{ tag : "site-name", description : "The name of the current site." },
		{ tag : "site-url",  description : "The site's address, from its primary domain." }
	];

	string function render( struct attributes = {}, string body = "", struct context = {} ){
		var siteId = val( arguments.context.siteId ?: 0 );

		switch ( arguments.context.tag ?: "" ) {
			case "year":
				return dateFormat( now(), "yyyy" );

			case "site-name":
				var site = siteId ? siteRepo.findById( siteId ) : javacast( "null", "" );

				// Escaped even though a site name is set by an administrator
				// rather than a visitor: a handler that trusts its inputs is
				// the habit that eventually writes an unescaped one.
				return isNull( site ) ? "" : arguments.context.escape( site.getName() );

			case "site-url":
				return arguments.context.escape( seo.baseUrl( siteId ) );
		}

		return "";
	}

}
