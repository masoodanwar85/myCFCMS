/**
 * Contributes a "FAQs" entry to a site's public navigation.
 *
 * Only when the site has at least one published FAQ: an empty accordion in
 * the menu is a dead end for a reader.
 */
component singleton accessors="true" {

	property name="faqService" inject="FaqService@faqs";
	property name="settings"   inject="coldbox:moduleSettings:faqs";

	array function getNavigationItems( required numeric siteId ){
		if ( !faqService.countPublishedFaqs( arguments.siteId ) ) {
			return [];
		}

		var base = reReplace( lCase( trim( settings.basePath ?: "faq" ) ), "^/+|/+$", "", "all" );

		return [
			{
				"label" : settings.pageTitle ?: "FAQs",
				"href"  : "/" & base,
				"order" : val( settings.navigationOrder ?: 800 )
			}
		];
	}

}
