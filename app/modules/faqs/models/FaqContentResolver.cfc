/**
 * Serves the public FAQ accordion at /faq.
 *
 * Claims only the module's base path. Anything else is declined so Pages
 * can still answer a page with a different slug.
 */
component singleton accessors="true" {

	property name="faqService" inject="FaqService@faqs";
	property name="shortcodes" inject="ShortcodeService@core";
	property name="settings"   inject="coldbox:moduleSettings:faqs";

	function resolveContent( required numeric siteId, required string path ){
		var base = basePath();

		if ( !len( base ) || arguments.path != base ) {
			return;
		}

		var faqs = faqService.getPublishedFaqs( arguments.siteId );

		for ( var faq in faqs ) {
			faq.setAnswer(
				shortcodes.expand(
					content = faq.getAnswer() ?: "",
					context = { "siteId" : arguments.siteId, "path" : base }
				)
			);
		}

		return {
			"view"            : "faq",
			"args"            : {
				"faqs"     : faqs,
				"basePath" : base
			},
			"title"           : pageTitle(),
			"metaDescription" : "",
			"statusCode"      : 200,
			"canonicalPath"   : base
		};
	}

	private string function basePath(){
		return reReplace( lCase( trim( settings.basePath ?: "faq" ) ), "^/+|/+$", "", "all" );
	}

	private string function pageTitle(){
		return settings.pageTitle ?: "FAQs";
	}

}
