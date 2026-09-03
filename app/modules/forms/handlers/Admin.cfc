/**
 * The Forms module's admin screens, at /admin/forms.
 *
 * Three permissions, split the way Contact's are: reading responses, building
 * forms, and deleting responses are different jobs. An assistant may need the
 * inbox without being able to send responses somewhere else.
 *
 * Every id that arrives in a URL is checked against the current site before
 * anything is done with it — an id is a guess anyone can make.
 */
component extends="core.models.security.SecuredHandler" {

	property name="formService" inject="FormService@forms";
	property name="fieldTypes"  inject="FieldTypes@forms";
	property name="paginator"   inject="Paginator@core";

	variables.permissions = {
		"index"       : "forms.view",
		"view"        : "forms.view",
		"status"      : "forms.view",
		"remove"      : "forms.submissions.delete",
		"forms"       : "forms.manage",
		"build"       : "forms.manage",
		"create"      : "forms.manage",
		"update"      : "forms.manage",
		"destroy"     : "forms.manage",
		"addField"    : "forms.manage",
		"updateField" : "forms.manage",
		"deleteField" : "forms.manage",
		"$every"      : "forms.view"
	};

	/* ------------------------------------------------------------- responses */

	function index( event, rc, prc ){
		var siteId = prc.currentSite.getId();

		prc.pageTitle = "Form responses";
		prc.filter    = listFindNoCase( "new,read,spam", rc.status ?: "" ) ? lCase( rc.status ) : "";
		prc.formId    = val( rc.formId ?: 0 );

		prc.forms = formService.getFormsForSite( siteId );

		// The filter must belong to this site, or a guessed id would list
		// another tenant's responses — the count would give it away even if the
		// rows did not.
		if ( prc.formId && !ownsForm( prc.formId, prc ) ) {
			prc.formId = 0;
		}

		prc.pagination = paginator.paginate(
			total   = formService.countSubmissions( siteId, prc.filter, prc.formId ),
			page    = paginator.readPage( rc.page ?: 1 ),
			perPage = 25
		);

		prc.submissions = formService.getSubmissions(
			siteId  = siteId,
			status  = prc.filter,
			formId  = prc.formId,
			limit   = prc.pagination.perPage,
			offset  = prc.pagination.offset
		);

		prc.canDelete = authorization.can( prc.currentUser, "forms.submissions.delete" );
		prc.canManage = authorization.can( prc.currentUser, "forms.manage" );

		event.setView( view = "admin/index", module = "forms" );
	}

	function view( event, rc, prc ){
		var submission = requireSiteSubmission( rc.id ?: 0, prc );

		// Opening a response is what marks it read. Doing it on the list would
		// mark everything read the moment somebody glanced at the inbox.
		if ( submission.isNewMessage() ) {
			formService.markSubmission( submission.getId(), "read" );
			submission.setStatus( "read" );
		}

		prc.pageTitle  = "Response";
		prc.submission = submission;
		prc.form       = formService.getFormById( submission.getFormId() );
		prc.canDelete  = authorization.can( prc.currentUser, "forms.submissions.delete" );

		event.setView( view = "admin/view", module = "forms" );
	}

	function status( event, rc, prc ){
		var submission = requireSiteSubmission( rc.id ?: 0, prc );

		try {
			formService.markSubmission( submission.getId(), rc.to ?: "" );
		} catch ( any e ) {
			return done( "/admin/forms", e.message, "error" );
		}

		return done( "/admin/forms", "Response marked #encodeForHTML( rc.to ?: '' )#." );
	}

	function remove( event, rc, prc ){
		var submission = requireSiteSubmission( rc.id ?: 0, prc );

		formService.deleteSubmission( submission.getId() );

		return done( "/admin/forms", "Response deleted." );
	}

	/* ----------------------------------------------------------------- forms */

	function forms( event, rc, prc ){
		var siteId = prc.currentSite.getId();

		prc.pageTitle = "Forms";
		prc.forms     = formService.getFormsForSite( siteId );

		// What a delete would take with it. A confirmation that says "and every
		// response" is worth nothing if the screen does not say how many.
		prc.counts = {};
		for ( var built in prc.forms ) {
			prc.counts[ built.getId() ] = formService.countSubmissionsForForm( built.getId() );
		}

		event.setView( view = "admin/forms", module = "forms" );
	}

	/**
	 * The builder: one form, its settings and its fields.
	 */
	function build( event, rc, prc ){
		var built = requireSiteForm( rc.id ?: 0, prc );

		prc.pageTitle  = built.getName();
		prc.form       = built;
		prc.fields     = formService.getFieldsForForm( built.getId() );
		prc.fieldTypes = fieldTypes.all();

		// Looked up once here rather than per row in the view: the list shows a
		// type badge for every field, and a view that called the registry in a
		// loop would be doing it for each of them.
		prc.typeLabels     = {};
		prc.typeHasOptions = {};
		for ( var type in prc.fieldTypes ) {
			prc.typeLabels[ type.key ]     = type.label;
			prc.typeHasOptions[ type.key ] = type.hasOptions;
		}

		prc.responses  = formService.countSubmissionsForForm( built.getId() );

		event.setView( view = "admin/build", module = "forms" );
	}

	function create( event, rc, prc ){
		try {
			var made = formService.createForm(
				siteId         = prc.currentSite.getId(),
				name           = rc.name ?: "",
				slug           = rc.slug ?: "",
				recipientEmail = rc.recipientEmail ?: ""
			);
		} catch ( any e ) {
			return done( "/admin/forms/forms", e.message, "error" );
		}

		// Straight into the builder: a form with no fields is not finished, and
		// the next thing anybody wants is to add one.
		return done( "/admin/forms/build/" & made.getId(), "Form created. Now add its fields." );
	}

	function update( event, rc, prc ){
		var built = requireSiteForm( rc.id ?: 0, prc );

		try {
			formService.updateForm(
				formId           = built.getId(),
				name             = rc.name ?: built.getName(),
				intro            = rc.intro ?: "",
				submitLabel      = rc.submitLabel ?: "",
				successMessage   = rc.successMessage ?: "",
				thankYouPath     = rc.thankYouPath ?: "",
				recipientEmail   = rc.recipientEmail ?: "",
				storeSubmissions = ( rc.storeSubmissions ?: "" ) == "yes",
				isActive         = ( rc.isActive ?: "" ) == "yes"
			);
		} catch ( any e ) {
			return done( "/admin/forms/build/" & built.getId(), e.message, "error" );
		}

		return done( "/admin/forms/build/" & built.getId(), "Form saved." );
	}

	function destroy( event, rc, prc ){
		var built = requireSiteForm( rc.id ?: 0, prc );

		// Responses go with it, by cascade. The confirmation on the screen says
		// how many, which is the only reason that is defensible.
		formService.deleteForm( built.getId() );

		return done( "/admin/forms/forms", "Form deleted." );
	}

	/* ---------------------------------------------------------------- fields */

	function addField( event, rc, prc ){
		var built = requireSiteForm( rc.id ?: 0, prc );

		try {
			formService.addField(
				formId      = built.getId(),
				fieldType   = rc.fieldType ?: "text",
				label       = rc.label ?: "",
				fieldKey    = rc.fieldKey ?: "",
				placeholder = rc.placeholder ?: "",
				helpText    = rc.helpText ?: "",
				optionsText = rc.optionsText ?: "",
				isRequired  = ( rc.isRequired ?: "" ) == "yes",
				maxLength   = val( rc.maxLength ?: 0 )
			);
		} catch ( any e ) {
			return done( "/admin/forms/build/" & built.getId(), e.message, "error" );
		}

		return done( "/admin/forms/build/" & built.getId(), "Field added." );
	}

	function updateField( event, rc, prc ){
		var field = requireSiteField( rc.id ?: 0, prc );

		try {
			formService.updateField(
				fieldId     = field.getId(),
				fieldType   = rc.fieldType ?: field.getFieldType(),
				label       = rc.label ?: field.getLabel(),
				placeholder = rc.placeholder ?: "",
				helpText    = rc.helpText ?: "",
				optionsText = rc.optionsText ?: "",
				isRequired  = ( rc.isRequired ?: "" ) == "yes",
				sortOrder   = val( rc.sortOrder ?: field.getSortOrder() ),
				// Zero and blank both mean "no limit", which is what the
				// service reads them as.
				maxLength   = val( rc.maxLength ?: 0 )
			);
		} catch ( any e ) {
			return done( "/admin/forms/build/" & field.getFormId(), e.message, "error" );
		}

		return done( "/admin/forms/build/" & field.getFormId(), "Field saved." );
	}

	function deleteField( event, rc, prc ){
		var field  = requireSiteField( rc.id ?: 0, prc );
		var formId = field.getFormId();

		formService.deleteField( field.getId() );

		return done( "/admin/forms/build/" & formId, "Field removed." );
	}

	/* --------------------------------------------------------------------- */

	private boolean function ownsForm( required numeric formId, required struct prc ){
		var built = formService.getFormById( arguments.formId );

		return !isNull( built ) && built.getSiteId() == arguments.prc.currentSite.getId();
	}

	private function requireSiteForm( required numeric id, required struct prc ){
		var built = formService.getFormById( arguments.id );

		if ( isNull( built ) || built.getSiteId() != arguments.prc.currentSite.getId() ) {
			throw( type = "Admin.NotFoundHere", message = "No form [#arguments.id#] on this site." );
		}

		return built;
	}

	private function requireSiteField( required numeric id, required struct prc ){
		var field = formService.getFieldById( arguments.id );

		if ( isNull( field ) || field.getSiteId() != arguments.prc.currentSite.getId() ) {
			throw( type = "Admin.NotFoundHere", message = "No field [#arguments.id#] on this site." );
		}

		return field;
	}

	private function requireSiteSubmission( required numeric id, required struct prc ){
		var submission = formService.getSubmissionById( arguments.id );

		if ( isNull( submission ) || submission.getSiteId() != arguments.prc.currentSite.getId() ) {
			throw( type = "Admin.NotFoundHere", message = "No response [#arguments.id#] on this site." );
		}

		return submission;
	}

}
