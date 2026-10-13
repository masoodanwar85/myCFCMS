/**
 * The shape of the URL itself.
 *
 * All notices, and all unfixable without a redirect — changing a published URL
 * costs more than any of these is worth, so these are findings for new pages
 * rather than instructions to rewrite old ones. The report says so.
 *
 * Underscores are included because Google treats a hyphen as a word separator
 * and an underscore as a joiner, so `will_creator` reads as one word. That is a
 * real if small difference, and it is free to get right before publishing.
 */
component singleton accessors="true" {

	this.ID = "url";

	// Long enough that no sensible path trips it; short enough to catch a slug
	// built by concatenating a whole sentence.
	variables.MAX_LENGTH = 115;

	array function inspect( required any document, required struct context ){
		var path  = trim( arguments.context.path ?: "" );
		var found = [];

		// The home page is served at the root and has no path to judge.
		if ( !len( path ) ) {
			return [];
		}

		if ( find( "_", path ) ) {
			found.append( {
				"checkId"  : "url.underscores",
				"severity" : "notice",
				"message"  : "The URL uses underscores. Hyphens separate words for a search engine; underscores join them.",
				"detail"   : "/" & path
			} );
		}

		if ( reFind( "[A-Z]", path ) ) {
			found.append( {
				"checkId"  : "url.uppercase",
				"severity" : "notice",
				"message"  : "The URL contains capital letters, which invites duplicate addresses for one page.",
				"detail"   : "/" & path
			} );
		}

		if ( len( path ) > variables.MAX_LENGTH ) {
			found.append( {
				"checkId"  : "url.tooLong",
				"severity" : "notice",
				"message"  : "The URL is #len( path )# characters long and will be truncated when displayed.",
				"detail"   : "/" & path
			} );
		}

		return found;
	}

}
