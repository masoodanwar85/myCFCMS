/**
 * FAQ use cases.
 *
 * Validate and sanitise here. Render nothing, know no HTTP. Answers are
 * sanitised unless the caller says the author holds `content.unfiltered`.
 */
component singleton accessors="true" {

	property name="faqRepository" inject="FaqRepository@faqs";
	property name="siteRepository" inject="SiteRepository@core";
	property name="sanitizer"      inject="ContentSanitizer@core";
	property name="wirebox"        inject="wirebox";

	/**
	 * @allowUnfilteredHtml Skip sanitising. The caller checks the permission.
	 *
	 * @throws Faqs.SiteNotFound
	 * @throws Faqs.InvalidFaq
	 */
	faqs.models.Faq function createFaq(
		required numeric siteId,
		required string question,
		string answer              = "",
		numeric sortOrder          = 0,
		boolean isPublished        = false,
		boolean allowUnfilteredHtml = false
	){
		if ( isNull( siteRepository.findById( arguments.siteId ) ) ) {
			throw( type = "Faqs.SiteNotFound", message = "No site with id [#arguments.siteId#]." );
		}

		var faqQuestion = trim( arguments.question );

		if ( !len( faqQuestion ) ) {
			throw( type = "Faqs.InvalidFaq", message = "A FAQ requires a question." );
		}

		var faq = wirebox
			.getInstance( "Faq@faqs" )
			.setSiteId( arguments.siteId )
			.setQuestion( faqQuestion )
			.setAnswer( sanitizer.sanitize( arguments.answer, arguments.allowUnfilteredHtml ) )
			.setSortOrder(
				val( arguments.sortOrder ) > 0
					? val( arguments.sortOrder )
					: faqRepository.nextSortOrder( arguments.siteId )
			)
			.setIsPublished( arguments.isPublished ? true : false );

		return faqRepository.create( faq );
	}

	/**
	 * @throws Faqs.FaqNotFound
	 * @throws Faqs.InvalidFaq
	 */
	faqs.models.Faq function updateFaq(
		required numeric faqId,
		required string question,
		string answer               = "",
		numeric sortOrder           = 0,
		boolean isPublished         = false,
		boolean allowUnfilteredHtml = false
	){
		var faq = requireFaq( arguments.faqId );

		var faqQuestion = trim( arguments.question );

		if ( !len( faqQuestion ) ) {
			throw( type = "Faqs.InvalidFaq", message = "A FAQ requires a question." );
		}

		faq.setQuestion( faqQuestion );
		faq.setAnswer( sanitizer.sanitize( arguments.answer, arguments.allowUnfilteredHtml ) );
		faq.setSortOrder( val( arguments.sortOrder ) );
		faq.setIsPublished( arguments.isPublished ? true : false );

		return faqRepository.update( faq );
	}

	faqs.models.Faq function publishFaq( required numeric faqId ){
		var faq = requireFaq( arguments.faqId );

		faq.setIsPublished( true );

		return faqRepository.update( faq );
	}

	faqs.models.Faq function unpublishFaq( required numeric faqId ){
		var faq = requireFaq( arguments.faqId );

		faq.setIsPublished( false );

		return faqRepository.update( faq );
	}

	function deleteFaq( required numeric faqId ){
		requireFaq( arguments.faqId );
		faqRepository.delete( arguments.faqId );

		return this;
	}

	function getFaqById( required numeric faqId ){
		return faqRepository.findById( arguments.faqId );
	}

	array function getFaqsForSite( required numeric siteId ){
		return faqRepository.findBySiteId( arguments.siteId );
	}

	numeric function countFaqsForSite( required numeric siteId ){
		return faqRepository.countBySiteId( arguments.siteId );
	}

	array function getPublishedFaqs( required numeric siteId ){
		return faqRepository.findPublished( arguments.siteId );
	}

	numeric function countPublishedFaqs( required numeric siteId ){
		return faqRepository.countPublished( arguments.siteId );
	}

	private function requireFaq( required numeric faqId ){
		var faq = faqRepository.findById( arguments.faqId );

		if ( isNull( faq ) ) {
			throw( type = "Faqs.FaqNotFound", message = "No FAQ with id [#arguments.faqId#]." );
		}

		return faq;
	}

}
