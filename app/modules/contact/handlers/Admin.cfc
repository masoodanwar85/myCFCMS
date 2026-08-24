/**
 * The Contact module's admin screens, at /admin/contact.
 *
 * Reading enquiries and configuring forms are guarded separately: an assistant
 * may need to triage the inbox without being able to change where enquiries are
 * delivered.
 */
component extends="core.models.security.SecuredHandler" {

	property name="contactService" inject="ContactService@contact";
	property name="paginator"      inject="Paginator@core";

	variables.permissions = {
		"index"      : "contact.view",
		"view"       : "contact.view",
		"status"     : "contact.view",
		"remove"     : "contact.submissions.delete",
		"forms"      : "contact.manage",
		"createForm" : "contact.manage",
		"updateForm" : "contact.manage",
		"deleteForm" : "contact.manage",
		"$every"     : "contact.view"
	};

	function index( event, rc, prc ){
		var siteId = prc.currentSite.getId();

		prc.pageTitle = "Enquiries";
		prc.filter    = listFindNoCase( "new,read,spam", rc.status ?: "" ) ? lCase( rc.status ) : "";

		// This list was capped at 100 with nothing to reach the rest, so a busy
		// site's older enquiries were simply invisible.
		prc.pagination = paginator.paginate(
			total   = contactService.countSubmissions( siteId, prc.filter ),
			page    = paginator.readPage( rc.page ?: 1 ),
			perPage = 25
		);
		prc.pageBase    = "/admin/contact" & ( len( prc.filter ) ? "?status=" & prc.filter : "" );
		prc.submissions = contactService.getSubmissions(
			siteId, prc.filter, prc.pagination.perPage, prc.pagination.offset
		);
		prc.newCount    = contactService.countNew( siteId );
		prc.forms       = contactService.getFormsForSite( siteId );

		prc.canDelete = authorization.can( prc.currentUser, "contact.submissions.delete" );
		prc.canManage = authorization.can( prc.currentUser, "contact.manage" );

		event.setView( view = "admin/index", module = "contact" );
	}

	function view( event, rc, prc ){
		var submission = requireSiteSubmission( rc.id ?: 0, prc );

		// Opening an enquiry is what marks it read; a separate button would be
		// one more thing to forget.
		if ( submission.isNew() ) {
			contactService.setStatus( submission.getId(), "read" );
			submission.setStatus( "read" );
		}

		prc.pageTitle  = "Enquiry";
		prc.submission = submission;
		prc.canDelete  = authorization.can( prc.currentUser, "contact.submissions.delete" );

		event.setView( view = "admin/view", module = "contact" );
	}

	function status( event, rc, prc ){
		var submission = requireSiteSubmission( rc.id ?: 0, prc );

		try {
			contactService.setStatus( submission.getId(), rc.to ?: "read" );
		} catch ( any e ) {
			return done( "/admin/contact", e.message, "error" );
		}

		return done( "/admin/contact", "Enquiry updated." );
	}

	function remove( event, rc, prc ){
		var submission = requireSiteSubmission( rc.id ?: 0, prc );

		contactService.deleteSubmission( submission.getId() );

		return done( "/admin/contact", "Enquiry deleted." );
	}

	/* ------------------------------------------------------------------ forms */

	function forms( event, rc, prc ){
		prc.pageTitle = "Contact forms";
		prc.forms     = contactService.getFormsForSite( prc.currentSite.getId() );

		event.setView( view = "admin/forms", module = "contact" );
	}

	function createForm( event, rc, prc ){
		try {
			contactService.createForm(
				siteId         = prc.currentSite.getId(),
				name           = rc.name ?: "",
				slug           = rc.slug ?: "",
				intro          = rc.intro ?: "",
				recipientEmail = rc.recipientEmail ?: ""
			);
		} catch ( any e ) {
			return done( "/admin/contact/forms", e.message, "error" );
		}

		return done( "/admin/contact/forms", "Form created." );
	}

	function updateForm( event, rc, prc ){
		var contactForm = requireSiteForm( rc.id ?: 0, prc );

		try {
			contactService.updateForm(
				formId         = contactForm.getId(),
				name           = rc.name ?: contactForm.getName(),
				intro          = rc.intro ?: "",
				recipientEmail = rc.recipientEmail ?: "",
				successMessage = rc.successMessage ?: "",
				isActive       = ( rc.isActive ?: "" ) == "yes"
			);
		} catch ( any e ) {
			return done( "/admin/contact/forms", e.message, "error" );
		}

		return done( "/admin/contact/forms", "Form saved." );
	}

	function deleteForm( event, rc, prc ){
		var contactForm = requireSiteForm( rc.id ?: 0, prc );

		// Deleting a form deletes every enquiry sent through it, by cascade.
		contactService.deleteForm( contactForm.getId() );

		return done( "/admin/contact/forms", "Form and its enquiries deleted." );
	}

	/* ---------------------------------------------------------------- helpers */

	private function requireSiteSubmission( required numeric id, required struct prc ){
		var submission = contactService.getSubmissionById( arguments.id );

		if ( isNull( submission ) || submission.getSiteId() != arguments.prc.currentSite.getId() ) {
			throw( type = "Admin.NotFoundHere", message = "No enquiry [#arguments.id#] on this site." );
		}

		return submission;
	}

	private function requireSiteForm( required numeric id, required struct prc ){
		var contactForm = contactService.getFormById( arguments.id );

		if ( isNull( contactForm ) || contactForm.getSiteId() != arguments.prc.currentSite.getId() ) {
			throw( type = "Admin.NotFoundHere", message = "No form [#arguments.id#] on this site." );
		}

		return contactForm;
	}

}
