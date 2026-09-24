/**
 * The FAQs module's own admin screens, at /admin/faqs.
 *
 * Extends Core's SecuredHandler, so the module depends on Core alone and never
 * on the admin module whose shell it appears inside.
 */
component extends="core.models.security.SecuredHandler" {

	property name="faqService" inject="FaqService@faqs";

	variables.permissions = {
		"index"     : "faqs.view",
		"new"       : "faqs.manage",
		"create"    : "faqs.manage",
		"edit"      : "faqs.manage",
		"update"    : "faqs.manage",
		"publish"   : "faqs.manage",
		"unpublish" : "faqs.manage",
		"remove"    : "faqs.manage",
		"$every"    : "faqs.view"
	};

	function index( event, rc, prc ){
		prc.pageTitle = "FAQs";
		prc.faqs      = faqService.getFaqsForSite( prc.currentSite.getId() );
		prc.canManage = authorization.can( prc.currentUser, "faqs.manage" );

		event.setView( view = "admin/index", module = "faqs" );
	}

	function new( event, rc, prc ){
		prc.pageTitle = "New FAQ";
		prc.faq       = "";
		prc.useEditor = true;

		event.setView( view = "admin/form", module = "faqs" );
	}

	function create( event, rc, prc ){
		try {
			faqService.createFaq(
				siteId              = prc.currentSite.getId(),
				question            = rc.question ?: "",
				answer              = rc.answer ?: "",
				sortOrder           = val( rc.sortOrder ?: 0 ),
				isPublished         = ( rc.isPublished ?: "" ) == "on",
				allowUnfilteredHtml = mayPostRawHtml( prc )
			);
		} catch ( any e ) {
			return done( "/admin/faqs/new", e.message, "error" );
		}

		return done( "/admin/faqs", "FAQ created." );
	}

	function edit( event, rc, prc ){
		prc.faq       = requireSiteFaq( rc.id ?: 0, prc );
		prc.pageTitle = "Edit FAQ";
		prc.useEditor = true;

		event.setView( view = "admin/form", module = "faqs" );
	}

	function update( event, rc, prc ){
		var faq = requireSiteFaq( rc.id ?: 0, prc );

		try {
			faqService.updateFaq(
				faqId               = faq.getId(),
				question            = rc.question ?: "",
				answer              = rc.answer ?: "",
				sortOrder           = val( rc.sortOrder ?: 0 ),
				isPublished         = ( rc.isPublished ?: "" ) == "on",
				allowUnfilteredHtml = mayPostRawHtml( prc )
			);
		} catch ( any e ) {
			return done( "/admin/faqs/edit/" & faq.getId(), e.message, "error" );
		}

		return done( "/admin/faqs", "FAQ saved." );
	}

	function publish( event, rc, prc ){
		faqService.publishFaq( requireSiteFaq( rc.id ?: 0, prc ).getId() );

		return done( "/admin/faqs", "FAQ published." );
	}

	function unpublish( event, rc, prc ){
		faqService.unpublishFaq( requireSiteFaq( rc.id ?: 0, prc ).getId() );

		return done( "/admin/faqs", "FAQ unpublished." );
	}

	function remove( event, rc, prc ){
		faqService.deleteFaq( requireSiteFaq( rc.id ?: 0, prc ).getId() );

		return done( "/admin/faqs", "FAQ deleted." );
	}

	private boolean function mayPostRawHtml( required struct prc ){
		return authorization.can( arguments.prc.currentUser, "content.unfiltered" );
	}

	private function requireSiteFaq( required numeric faqId, required struct prc ){
		var faq = faqService.getFaqById( arguments.faqId );

		if ( isNull( faq ) || faq.getSiteId() != arguments.prc.currentSite.getId() ) {
			throw( type = "Admin.NotFoundHere", message = "No FAQ [#arguments.faqId#] on this site." );
		}

		return faq;
	}

}
