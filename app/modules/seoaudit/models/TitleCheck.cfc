/**
 * The `<title>`.
 *
 * The most valuable single element on the page and the one most often left to
 * whatever the CMS generates. Length bounds are not rules — Google has never
 * published one — they are where a title starts getting truncated in a result
 * on a typical screen. So a title outside them is a warning, never an error:
 * the page works, it just shows less of itself than it could.
 *
 * A *missing* title is an error, because a result with no title is a result
 * nobody clicks.
 */
component singleton accessors="true" {

	property name="settings" inject="coldbox:moduleSettings:seoaudit";

	this.ID = "title";

	array function inspect( required any document, required struct context ){
		var title = arguments.document.title();
		var found = [];

		if ( !len( title ) ) {
			return [ {
				"checkId"  : "title.missing",
				"severity" : "error",
				"message"  : "This page has no title. Search results and browser tabs will show the URL instead.",
				"detail"   : ""
			} ];
		}

		var minimum = val( settings.titleMin ?: 30 );
		var maximum = val( settings.titleMax ?: 60 );

		if ( len( title ) < minimum ) {
			found.append( {
				"checkId"  : "title.tooShort",
				"severity" : "warning",
				"message"  : "The title is shorter than #minimum# characters, which wastes room a result could use.",
				"detail"   : "#len( title )# characters: #title#"
			} );
		}

		if ( len( title ) > maximum ) {
			found.append( {
				"checkId"  : "title.tooLong",
				"severity" : "warning",
				"message"  : "The title is longer than #maximum# characters and will likely be truncated in results.",
				"detail"   : "#len( title )# characters: #title#"
			} );
		}

		// A title that is only the site name tells a reader nothing about the
		// page, and every page on the site competes with itself in results.
		var siteName = trim( arguments.context.siteName ?: "" );

		if ( len( siteName ) && compareNoCase( title, siteName ) == 0 ) {
			found.append( {
				"checkId"  : "title.siteNameOnly",
				"severity" : "warning",
				"message"  : "The title is just the site name, so this page is indistinguishable from the others in results.",
				"detail"   : title
			} );
		}

		return found;
	}

}
