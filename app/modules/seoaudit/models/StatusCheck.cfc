/**
 * Did the URL answer at all?
 *
 * Runs first, and it is the only check whose finding makes the others
 * meaningless: a 404 has no title to be too long. The run skips the remaining
 * checks when this one reports, so a broken URL produces one clear finding
 * rather than nine confusing ones.
 */
component singleton accessors="true" {

	this.ID = "status";

	array function inspect( required any document, required struct context ){
		var code = val( arguments.context.statusCode ?: 0 );

		if ( code == 200 ) {
			// A 200 that could not be parsed is its own problem, and worth
			// saying out loud: every other check silently found nothing.
			if ( !arguments.document.isParsed() ) {
				return [ {
					"checkId"  : "status.unparseable",
					"severity" : "error",
					"message"  : "The page answered but its HTML could not be read, so nothing else could be checked.",
					"detail"   : arguments.document.getParseError()
				} ];
			}

			return [];
		}

		if ( code >= 300 && code < 400 ) {
			return [ {
				"checkId"  : "status.redirect",
				"severity" : "warning",
				"message"  : "This URL redirects. A redirected URL should not be the one advertised in the sitemap or linked internally.",
				"detail"   : "HTTP #code#" & ( len( arguments.context.location ?: "" ) ? " to " & arguments.context.location : "" )
			} ];
		}

		if ( !code ) {
			return [ {
				"checkId"  : "status.unreachable",
				"severity" : "error",
				"message"  : "This URL could not be fetched at all.",
				"detail"   : arguments.context.fetchError ?: ""
			} ];
		}

		return [ {
			"checkId"  : "status.error",
			"severity" : "error",
			"message"  : "This URL answers with an error, so a crawler cannot index it.",
			"detail"   : "HTTP #code#"
		} ];
	}

}
