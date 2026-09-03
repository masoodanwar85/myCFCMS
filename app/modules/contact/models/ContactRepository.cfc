/**
 * Persistence for contact forms and the messages sent through them.
 */
component singleton extends="core.models.persistence.BaseRepository" {

	variables.FORM_TABLE = "contact_forms";
	variables.FORM_COLS  = [
		"id", "site_id", "name", "slug", "intro",
		"recipient_email", "success_message", "thank_you_path", "is_active", "created_at", "updated_at"
	];

	variables.SUB_TABLE = "contact_submissions";
	variables.SUB_COLS  = [
		"id", "site_id", "form_id", "name", "email", "subject",
		"message", "status", "ip_address", "user_agent", "created_at", "updated_at"
	];

	/* ------------------------------------------------------------------ forms */

	contact.models.ContactForm function createForm( required contact.models.ContactForm form ){
		var stamp  = now();
		var result = "";

		try {
			result = variables.query
				.from( variables.FORM_TABLE )
				.insert( {
					"site_id"         : arguments.form.getSiteId(),
					"name"            : arguments.form.getName(),
					"slug"            : arguments.form.getSlug(),
					"intro"           : { value : arguments.form.getIntro() ?: "", cfsqltype : "cf_sql_longvarchar" },
					"recipient_email" : arguments.form.getRecipientEmail() ?: "",
					"success_message" : arguments.form.getSuccessMessage(),
					"thank_you_path"  : arguments.form.getThankYouPath() ?: "",
					"is_active"       : arguments.form.getIsActive() ? 1 : 0,
					"created_at"      : { value : stamp, cfsqltype : "cf_sql_timestamp" },
					"updated_at"      : { value : stamp, cfsqltype : "cf_sql_timestamp" }
				} );
		} catch ( any e ) {
			if ( !isUniqueViolation( e ) ) {
				rethrow;
			}
			throw(
				type    = "Contact.FormSlugExists",
				message = "This site already has a form at [#arguments.form.getSlug()#].",
				detail  = e.message
			);
		}

		arguments.form.setId( generatedKey( result, variables.FORM_TABLE ) );

		return arguments.form;
	}

	contact.models.ContactForm function updateForm( required contact.models.ContactForm form ){
		variables.query
			.from( variables.FORM_TABLE )
			.where( "id", arguments.form.getId() )
			.update( {
				"name"            : arguments.form.getName(),
				"intro"           : { value : arguments.form.getIntro() ?: "", cfsqltype : "cf_sql_longvarchar" },
				"recipient_email" : arguments.form.getRecipientEmail() ?: "",
				"success_message" : arguments.form.getSuccessMessage(),
				"thank_you_path"  : arguments.form.getThankYouPath() ?: "",
				"is_active"       : arguments.form.getIsActive() ? 1 : 0,
				"updated_at"      : { value : now(), cfsqltype : "cf_sql_timestamp" }
			} );

		return arguments.form;
	}

	function findFormById( required numeric id ){
		return toFormOrNull( formQuery().where( "id", arguments.id ).first() );
	}

	/**
	 * @activeOnly Restrict to a form that is currently accepting messages.
	 *             The public site always passes true: `is_active` is meant to
	 *             stop a form receiving anything, and a lookup that ignored it
	 *             meant a deactivated form still accepted submissions from
	 *             anyone who knew its slug. The admin passes false, because it
	 *             has to be able to load a form in order to switch it back on.
	 */
	function findFormBySlug(
		required numeric siteId,
		required string slug,
		boolean activeOnly = false
	){
		var q = formQuery().where( "site_id", arguments.siteId ).where( "slug", arguments.slug );

		if ( arguments.activeOnly ) {
			q.where( "is_active", 1 );
		}

		return toFormOrNull( q.first() );
	}

	array function findFormsForSite( required numeric siteId ){
		return formQuery()
			.where( "site_id", arguments.siteId )
			.orderBy( "id" )
			.get()
			.map( ( row ) => toForm( row ) );
	}

	/**
	 * A site's contact form.
	 *
	 * Oldest active row, by id. Deliberately not `orderBy( "name" )`, which is
	 * what decided this before: which form a site served was then decided
	 * alphabetically, so renaming a form could silently change which one
	 * `/contact` showed. Id ordering is stable and means "the one you set up
	 * first", which is the one a site has been using.
	 */
	function findFormForSite( required numeric siteId ){
		return toFormOrNull(
			formQuery()
				.where( "site_id", arguments.siteId )
				.where( "is_active", 1 )
				.orderBy( "id" )
				.first()
		);
	}

	numeric function countFormsForSite( required numeric siteId ){
		return variables.query.from( variables.FORM_TABLE ).where( "site_id", arguments.siteId ).count();
	}

	function deleteForm( required numeric formId ){
		variables.query.from( variables.FORM_TABLE ).where( "id", arguments.formId ).delete();
		return this;
	}

	/* ------------------------------------------------------------ submissions */

	/**
	 * @throws Contact.CrossTenantForm when the form is not the site's.
	 */
	contact.models.Submission function createSubmission( required contact.models.Submission submission ){
		var stamp  = now();
		var result = "";

		try {
			result = variables.query
				.from( variables.SUB_TABLE )
				.insert( {
					"site_id"    : arguments.submission.getSiteId(),
					"form_id"    : arguments.submission.getFormId(),
					"name"       : arguments.submission.getName(),
					"email"      : arguments.submission.getEmail(),
					"subject"    : arguments.submission.getSubject() ?: "",
					"message"    : { value : arguments.submission.getMessage(), cfsqltype : "cf_sql_longvarchar" },
					"status"     : arguments.submission.getStatus(),
					"ip_address" : arguments.submission.getIpAddress() ?: "",
					"user_agent" : left( arguments.submission.getUserAgent() ?: "", 255 ),
					"created_at" : { value : stamp, cfsqltype : "cf_sql_timestamp" },
					"updated_at" : { value : stamp, cfsqltype : "cf_sql_timestamp" }
				} );
		} catch ( any e ) {
			if ( !isForeignKeyViolation( e ) ) {
				rethrow;
			}
			throw(
				type    = "Contact.CrossTenantForm",
				message = "Form [#arguments.submission.getFormId()#] does not belong to site [#arguments.submission.getSiteId()#].",
				detail  = e.message
			);
		}

		arguments.submission.setId( generatedKey( result, variables.SUB_TABLE ) );
		arguments.submission.setCreatedAt( stamp );

		return arguments.submission;
	}

	function findSubmissionById( required numeric id ){
		return toSubmissionOrNull( subQuery().where( "id", arguments.id ).first() );
	}

	/**
	 * A site's submissions, newest first.
	 *
	 * @status Optional filter: `new`, `read` or `spam`.
	 */
	array function findSubmissionsForSite(
		required numeric siteId,
		string status  = "",
		numeric limit  = 25,
		numeric offset = 0
	){
		var q = subQuery().where( "site_id", arguments.siteId );

		if ( len( arguments.status ) ) {
			q.where( "status", arguments.status );
		}

		return q
			.orderBy( "created_at", "desc" )
			.orderBy( "id", "desc" )
			.limit( arguments.limit )
			.offset( arguments.offset )
			.get()
			.map( ( row ) => toSubmission( row ) );
	}

	/**
	 * How many submissions a site has, optionally of one status.
	 */
	numeric function countSubmissionsForSite( required numeric siteId, string status = "" ){
		var q = variables.query.from( variables.SUB_TABLE ).where( "site_id", arguments.siteId );

		if ( len( arguments.status ) ) {
			q.where( "status", arguments.status );
		}

		return q.count();
	}

	numeric function countSubmissionsForForm( required numeric formId ){
		return variables.query.from( variables.SUB_TABLE ).where( "form_id", arguments.formId ).count();
	}

	numeric function countByStatus( required numeric siteId, required string status ){
		return variables.query
			.from( variables.SUB_TABLE )
			.where( "site_id", arguments.siteId )
			.where( "status", arguments.status )
			.count();
	}

	/**
	 * How many messages this address sent since a given moment.
	 *
	 * Used to throttle a flood from one sender without any extra storage.
	 */
	numeric function countRecentFrom(
		required numeric siteId,
		required string ipAddress,
		required any since
	){
		return variables.query
			.from( variables.SUB_TABLE )
			.where( "site_id", arguments.siteId )
			.where( "ip_address", arguments.ipAddress )
			.where( "created_at", ">=", { value : arguments.since, cfsqltype : "cf_sql_timestamp" } )
			.count();
	}

	function updateSubmissionStatus( required numeric submissionId, required string status ){
		variables.query
			.from( variables.SUB_TABLE )
			.where( "id", arguments.submissionId )
			.update( {
				"status"     : arguments.status,
				"updated_at" : { value : now(), cfsqltype : "cf_sql_timestamp" }
			} );

		return this;
	}

	function deleteSubmission( required numeric submissionId ){
		variables.query.from( variables.SUB_TABLE ).where( "id", arguments.submissionId ).delete();
		return this;
	}

	/* ---------------------------------------------------------------- mapping */

	contact.models.ContactForm function toForm( required struct row ){
		return wirebox
			.getInstance( "ContactForm@contact" )
			.setId( arguments.row.id )
			.setSiteId( arguments.row.site_id )
			.setName( arguments.row.name )
			.setSlug( arguments.row.slug )
			.setIntro( arguments.row.intro ?: "" )
			.setRecipientEmail( arguments.row.recipient_email ?: "" )
			.setSuccessMessage( arguments.row.success_message )
			.setThankYouPath( arguments.row.thank_you_path ?: "" )
			.setIsActive( arguments.row.is_active ? true : false );
	}

	contact.models.Submission function toSubmission( required struct row ){
		return wirebox
			.getInstance( "Submission@contact" )
			.setId( arguments.row.id )
			.setSiteId( arguments.row.site_id )
			.setFormId( arguments.row.form_id )
			.setName( arguments.row.name )
			.setEmail( arguments.row.email )
			.setSubject( arguments.row.subject ?: "" )
			.setMessage( arguments.row.message )
			.setStatus( arguments.row.status )
			.setIpAddress( arguments.row.ip_address ?: "" )
			.setUserAgent( arguments.row.user_agent ?: "" )
			.setCreatedAt( arguments.row.created_at )
			.setUpdatedAt( arguments.row.updated_at );
	}

	private function formQuery(){
		return variables.query.from( variables.FORM_TABLE ).select( variables.FORM_COLS );
	}

	private function subQuery(){
		return variables.query.from( variables.SUB_TABLE ).select( variables.SUB_COLS );
	}

	private function toFormOrNull( required struct row ){
		if ( arguments.row.isEmpty() ) {
			return;
		}
		return toForm( arguments.row );
	}

	private function toSubmissionOrNull( required struct row ){
		if ( arguments.row.isEmpty() ) {
			return;
		}
		return toSubmission( arguments.row );
	}

}
