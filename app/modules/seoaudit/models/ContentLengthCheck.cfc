/**
 * Thin content.
 *
 * The threshold is deliberately low, and the reason is in `HtmlDocument`:
 * the word count includes navigation, header and footer text, because those
 * are words on the page and a crawler reads them. Excluding them would mean
 * deciding what counts as content, which is a judgement rather than a
 * measurement.
 *
 * The consequence is that the count overstates how much a page actually says,
 * so a threshold set where "good content" begins would almost never fire. Set
 * low, it catches what it is meant to catch: the page with a heading and one
 * sentence.
 */
component singleton accessors="true" {

	property name="settings" inject="coldbox:moduleSettings:seoaudit";

	this.ID = "content";

	array function inspect( required any document, required struct context ){
		var words     = arguments.document.wordCount();
		var threshold = val( settings.thinContent ?: 300 );

		if ( words >= threshold ) {
			return [];
		}

		return [ {
			"checkId"  : "content.thin",
			"severity" : "warning",
			"message"  : "Only #words# words on the page, including menus and footer. There may be too little here to rank for anything.",
			"detail"   : "Threshold: #threshold# words"
		} ];
	}

}
