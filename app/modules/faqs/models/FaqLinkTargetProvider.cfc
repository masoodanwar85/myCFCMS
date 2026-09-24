/**
 * Lets a menu item point at the public FAQ accordion.
 *
 * Offered as `faq.page` with a fixed id of 0: there is only ever one listing,
 * and it has no row of its own. Storing the type rather than a typed URL
 * means it follows the module's `basePath` setting if that is ever changed.
 */
component singleton accessors="true" {

	property name="faqService" inject="FaqService@faqs";
	property name="settings"   inject="coldbox:moduleSettings:faqs";

	this.PAGE = "faq.page";

	array function getLinkTargets( required numeric siteId ){
		if ( !faqService.countPublishedFaqs( arguments.siteId ) ) {
			return [];
		}

		return [
			{
				"type"  : this.PAGE,
				"id"    : 0,
				"label" : settings.pageTitle ?: "FAQs",
				"path"  : basePath(),
				"group" : "FAQs"
			}
		];
	}

	function resolveLinkTarget( required numeric siteId, required string type, required numeric id ){
		if ( arguments.type != this.PAGE ) {
			return;
		}

		if ( !faqService.countPublishedFaqs( arguments.siteId ) ) {
			return;
		}

		return {
			"label" : settings.pageTitle ?: "FAQs",
			"path"  : basePath()
		};
	}

	private string function basePath(){
		return reReplace( lCase( trim( settings.basePath ?: "faq" ) ), "^/+|/+$", "", "all" );
	}

}
