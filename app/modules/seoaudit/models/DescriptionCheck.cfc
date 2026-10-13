/**
 * The meta description.
 *
 * It is not a ranking factor and has not been one for years. It is the sales
 * copy under the link, so the cost of getting it wrong is click-through rather
 * than position — which is why nothing here is an error. A missing description
 * means the engine writes one by quoting the page, usually badly; that is a
 * warning, not a fault.
 */
component singleton accessors="true" {

	property name="settings" inject="coldbox:moduleSettings:seoaudit";

	this.ID = "description";

	array function inspect( required any document, required struct context ){
		var description = arguments.document.metaByName( "description" );
		var found       = [];

		if ( !len( description ) ) {
			return [ {
				"checkId"  : "description.missing",
				"severity" : "warning",
				"message"  : "No meta description, so search engines will quote whatever text they find on the page.",
				"detail"   : ""
			} ];
		}

		var minimum = val( settings.descriptionMin ?: 70 );
		var maximum = val( settings.descriptionMax ?: 160 );

		if ( len( description ) < minimum ) {
			found.append( {
				"checkId"  : "description.tooShort",
				"severity" : "warning",
				"message"  : "The description is under #minimum# characters and leaves room unused.",
				"detail"   : "#len( description )# characters: #description#"
			} );
		}

		if ( len( description ) > maximum ) {
			found.append( {
				"checkId"  : "description.tooLong",
				"severity" : "warning",
				"message"  : "The description is over #maximum# characters and will be cut off mid-sentence.",
				"detail"   : "#len( description )# characters: #description#"
			} );
		}

		return found;
	}

}
