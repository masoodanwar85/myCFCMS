/**
 * The Will module's admin screens, at /admin/will.
 */
component extends="core.models.security.SecuredHandler" {

	property name="willService" inject="WillService@will";
	property name="paginator"   inject="Paginator@core";

	variables.permissions = {
		"index"  : "will.view",
		"view"   : "will.view",
		"remove" : "will.submissions.delete",
		"$every" : "will.view"
	};

	function index( event, rc, prc ){
		var siteId = prc.currentSite.getId();

		prc.pageTitle  = "Wills";
		prc.pagination = paginator.paginate(
			total   = willService.countSubmissions( siteId ),
			page    = paginator.readPage( rc.page ?: 1 ),
			perPage = 25
		);
		prc.pageBase    = "/admin/will";
		prc.submissions = willService.getSubmissions(
			siteId, prc.pagination.perPage, prc.pagination.offset
		);
		prc.canDelete = authorization.can( prc.currentUser, "will.submissions.delete" );

		event.setView( view = "admin/index", module = "will" );
	}

	function view( event, rc, prc ){
		var submission = requireSiteSubmission( rc.id ?: 0, prc );

		prc.pageTitle  = "Will";
		prc.submission = submission;
		prc.related    = willService.getRelated( submission );
		prc.canDelete  = authorization.can( prc.currentUser, "will.submissions.delete" );

		event.setView( view = "admin/view", module = "will" );
	}

	function remove( event, rc, prc ){
		var submission = requireSiteSubmission( rc.id ?: 0, prc );

		willService.deleteSubmission( submission.getId() );

		return done( "/admin/will", "Will submission deleted." );
	}

	private function requireSiteSubmission( required numeric id, required struct prc ){
		var submission = willService.getSubmissionById( arguments.id );

		if ( isNull( submission ) || submission.getSiteId() != arguments.prc.currentSite.getId() ) {
			throw( type = "Admin.NotFoundHere", message = "No will [#arguments.id#] on this site." );
		}

		return submission;
	}

}
