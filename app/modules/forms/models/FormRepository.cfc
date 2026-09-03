/**
 * Persistence for forms, their fields and the responses sent through them.
 */
component singleton extends="core.models.persistence.BaseRepository" {

	variables.FORM_TABLE = "forms";
	variables.FORM_COLS  = [
		"id", "site_id", "name", "slug", "intro", "submit_label", "success_message",
		"thank_you_path", "recipient_email", "store_submissions", "is_active",
		"created_at", "updated_at"
	];

	variables.FIELD_TABLE = "form_fields";
	variables.FIELD_COLS  = [
		"id", "site_id", "form_id", "field_type", "field_key", "label", "placeholder",
		"help_text", "options_text", "is_required", "max_length", "sort_order",
		"created_at", "updated_at"
	];

	variables.SUB_TABLE = "form_submissions";
	variables.SUB_COLS  = [
		"id", "site_id", "form_id", "answers", "sender_email", "summary",
		"status", "ip_address", "user_agent", "created_at", "updated_at"
	];

	/* ------------------------------------------------------------------ forms */

	/**
	 * @throws Forms.SlugExists when the site already has a form at that slug.
	 */
	forms.models.Form function createForm( required forms.models.Form form ){
		var stamp  = now();
		var result = "";

		try {
			result = variables.query
				.from( variables.FORM_TABLE )
				.insert( {
					"site_id"           : arguments.form.getSiteId(),
					"name"              : arguments.form.getName(),
					"slug"              : arguments.form.getSlug(),
					"intro"             : { value : arguments.form.getIntro() ?: "", cfsqltype : "cf_sql_longvarchar" },
					"submit_label"      : arguments.form.getSubmitLabel(),
					"success_message"   : arguments.form.getSuccessMessage(),
					"thank_you_path"    : arguments.form.getThankYouPath() ?: "",
					"recipient_email"   : arguments.form.getRecipientEmail() ?: "",
					// `null : false` throughout: these columns are NOT NULL
					// with defaults, and qb infers a null bind from a falsy
					// value, which MySQL then refuses to fall back on.
					"store_submissions" : flag( arguments.form.getStoreSubmissions() ),
					"is_active"         : flag( arguments.form.getIsActive() ),
					"created_at"        : { value : stamp, cfsqltype : "cf_sql_timestamp" },
					"updated_at"        : { value : stamp, cfsqltype : "cf_sql_timestamp" }
				} );
		} catch ( any e ) {
			if ( !isUniqueViolation( e ) ) {
				rethrow;
			}
			throw(
				type    = "Forms.SlugExists",
				message = "This site already has a form at [#arguments.form.getSlug()#].",
				detail  = e.message
			);
		}

		arguments.form.setId( generatedKey( result, variables.FORM_TABLE ) );

		return arguments.form;
	}

	forms.models.Form function updateForm( required forms.models.Form form ){
		variables.query
			.from( variables.FORM_TABLE )
			.where( "id", arguments.form.getId() )
			.update( {
				"name"              : arguments.form.getName(),
				"intro"             : { value : arguments.form.getIntro() ?: "", cfsqltype : "cf_sql_longvarchar" },
				"submit_label"      : arguments.form.getSubmitLabel(),
				"success_message"   : arguments.form.getSuccessMessage(),
				"thank_you_path"    : arguments.form.getThankYouPath() ?: "",
				"recipient_email"   : arguments.form.getRecipientEmail() ?: "",
				"store_submissions" : flag( arguments.form.getStoreSubmissions() ),
				"is_active"         : flag( arguments.form.getIsActive() ),
				"updated_at"        : { value : now(), cfsqltype : "cf_sql_timestamp" }
			} );

		return arguments.form;
	}

	function findFormById( required numeric id ){
		return toFormOrNull( formQuery().where( "id", arguments.id ).first() );
	}

	/**
	 * @activeOnly What the public site always wants: a form switched off should
	 *             vanish from the page rather than render and then refuse what
	 *             is sent to it.
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
			.orderBy( "name" )
			.get()
			.map( ( row ) => toForm( row ) );
	}

	function deleteForm( required numeric formId ){
		variables.query.from( variables.FORM_TABLE ).where( "id", arguments.formId ).delete();
		return this;
	}

	/* ----------------------------------------------------------------- fields */

	forms.models.FormField function createField( required forms.models.FormField field ){
		var stamp  = now();
		var result = "";

		try {
			result = variables.query
				.from( variables.FIELD_TABLE )
				.insert( fieldRow( arguments.field, stamp ) );
		} catch ( any e ) {
			if ( !isUniqueViolation( e ) ) {
				rethrow;
			}
			throw(
				type    = "Forms.FieldKeyExists",
				message = "This form already has a field named [#arguments.field.getFieldKey()#].",
				detail  = e.message
			);
		}

		arguments.field.setId( generatedKey( result, variables.FIELD_TABLE ) );

		return arguments.field;
	}

	forms.models.FormField function updateField( required forms.models.FormField field ){
		var row = fieldRow( arguments.field, now() );

		// The key is fixed once answers may exist under it, so it is not in the
		// update at all rather than being quietly ignored.
		structDelete( row, "field_key" );
		structDelete( row, "created_at" );
		structDelete( row, "form_id" );
		structDelete( row, "site_id" );

		variables.query.from( variables.FIELD_TABLE ).where( "id", arguments.field.getId() ).update( row );

		return arguments.field;
	}

	function findFieldById( required numeric id ){
		var row = fieldQuery().where( "id", arguments.id ).first();

		return row.isEmpty() ? javacast( "null", "" ) : toField( row );
	}

	array function findFieldsForForm( required numeric formId ){
		return fieldQuery()
			.where( "form_id", arguments.formId )
			.orderBy( "sort_order" )
			.orderBy( "id" )
			.get()
			.map( ( row ) => toField( row ) );
	}

	function deleteField( required numeric fieldId ){
		variables.query.from( variables.FIELD_TABLE ).where( "id", arguments.fieldId ).delete();
		return this;
	}

	numeric function nextSortOrder( required numeric formId ){
		// `selectRaw`, not `select`: qb quotes a `select()` argument as a column
		// name, so the aggregate became `` `MAX(sort_order)` `` and MySQL
		// reported an unknown column.
		var row = variables.query
			.from( variables.FIELD_TABLE )
			.selectRaw( "MAX(sort_order) AS top" )
			.where( "form_id", arguments.formId )
			.first();

		return val( row.top ?: 0 ) + 10;
	}

	/* ------------------------------------------------------------ submissions */

	/**
	 * @throws Forms.CrossTenantForm when the form is not the site's.
	 */
	forms.models.FormSubmission function createSubmission( required forms.models.FormSubmission submission ){
		var stamp  = now();
		var result = "";

		try {
			result = variables.query
				.from( variables.SUB_TABLE )
				.insert( {
					"site_id"      : arguments.submission.getSiteId(),
					"form_id"      : arguments.submission.getFormId(),
					// Serialised here rather than by the caller, so the one
					// place that writes the column is the one that reads it.
					"answers"      : { value : serializeJSON( arguments.submission.getAnswers() ), cfsqltype : "cf_sql_longvarchar" },
					"sender_email" : arguments.submission.getSenderEmail() ?: "",
					"summary"      : left( arguments.submission.getSummary() ?: "", 255 ),
					"status"       : arguments.submission.getStatus(),
					"ip_address"   : arguments.submission.getIpAddress() ?: "",
					"user_agent"   : left( arguments.submission.getUserAgent() ?: "", 255 ),
					"created_at"   : { value : stamp, cfsqltype : "cf_sql_timestamp" },
					"updated_at"   : { value : stamp, cfsqltype : "cf_sql_timestamp" }
				} );
		} catch ( any e ) {
			if ( !isForeignKeyViolation( e ) ) {
				rethrow;
			}
			throw(
				type    = "Forms.CrossTenantForm",
				message = "Form [#arguments.submission.getFormId()#] does not belong to site [#arguments.submission.getSiteId()#].",
				detail  = e.message
			);
		}

		arguments.submission.setId( generatedKey( result, variables.SUB_TABLE ) );
		arguments.submission.setCreatedAt( stamp );

		return arguments.submission;
	}

	function findSubmissionById( required numeric id ){
		var row = subQuery().where( "id", arguments.id ).first();

		return row.isEmpty() ? javacast( "null", "" ) : toSubmission( row );
	}

	array function findSubmissionsForSite(
		required numeric siteId,
		string status   = "",
		numeric formId  = 0,
		numeric limit   = 25,
		numeric offset  = 0
	){
		var q = subQuery().where( "site_id", arguments.siteId );

		if ( len( arguments.status ) ) {
			q.where( "status", arguments.status );
		}
		if ( arguments.formId ) {
			q.where( "form_id", arguments.formId );
		}

		return q
			.orderBy( "created_at", "desc" )
			.orderBy( "id", "desc" )
			.limit( arguments.limit )
			.offset( arguments.offset )
			.get()
			.map( ( row ) => toSubmission( row ) );
	}

	numeric function countSubmissionsForSite(
		required numeric siteId,
		string status  = "",
		numeric formId = 0
	){
		var q = variables.query.from( variables.SUB_TABLE ).where( "site_id", arguments.siteId );

		if ( len( arguments.status ) ) {
			q.where( "status", arguments.status );
		}
		if ( arguments.formId ) {
			q.where( "form_id", arguments.formId );
		}

		return q.count();
	}

	numeric function countSubmissionsForForm( required numeric formId ){
		return variables.query.from( variables.SUB_TABLE ).where( "form_id", arguments.formId ).count();
	}

	/**
	 * How many responses this address sent since a given moment, for throttling
	 * a flood without any extra storage.
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

	forms.models.Form function toForm( required struct row ){
		return wirebox
			.getInstance( "Form@forms" )
			.setId( arguments.row.id )
			.setSiteId( arguments.row.site_id )
			.setName( arguments.row.name )
			.setSlug( arguments.row.slug )
			.setIntro( arguments.row.intro ?: "" )
			.setSubmitLabel( arguments.row.submit_label )
			.setSuccessMessage( arguments.row.success_message )
			.setThankYouPath( arguments.row.thank_you_path ?: "" )
			.setRecipientEmail( arguments.row.recipient_email ?: "" )
			.setStoreSubmissions( arguments.row.store_submissions ? true : false )
			.setIsActive( arguments.row.is_active ? true : false )
			.setCreatedAt( arguments.row.created_at )
			.setUpdatedAt( arguments.row.updated_at );
	}

	forms.models.FormField function toField( required struct row ){
		var field = wirebox
			.getInstance( "FormField@forms" )
			.setId( arguments.row.id )
			.setSiteId( arguments.row.site_id )
			.setFormId( arguments.row.form_id )
			.setFieldType( arguments.row.field_type )
			.setFieldKey( arguments.row.field_key )
			.setLabel( arguments.row.label )
			.setPlaceholder( arguments.row.placeholder ?: "" )
			.setHelpText( arguments.row.help_text ?: "" )
			.setOptionsText( arguments.row.options_text ?: "" )
			.setIsRequired( arguments.row.is_required ? true : false )
			.setSortOrder( arguments.row.sort_order )
			.setCreatedAt( arguments.row.created_at )
			.setUpdatedAt( arguments.row.updated_at );

		// Left unset when null, so "no limit" stays distinguishable from zero.
		if ( !isNull( arguments.row.max_length ) && len( arguments.row.max_length ) ) {
			field.setMaxLength( arguments.row.max_length );
		}

		return field;
	}

	forms.models.FormSubmission function toSubmission( required struct row ){
		return wirebox
			.getInstance( "FormSubmission@forms" )
			.setId( arguments.row.id )
			.setSiteId( arguments.row.site_id )
			.setFormId( arguments.row.form_id )
			.setAnswers( decodeAnswers( arguments.row.answers ?: "" ) )
			.setSenderEmail( arguments.row.sender_email ?: "" )
			.setSummary( arguments.row.summary ?: "" )
			.setStatus( arguments.row.status )
			.setIpAddress( arguments.row.ip_address ?: "" )
			.setUserAgent( arguments.row.user_agent ?: "" )
			.setCreatedAt( arguments.row.created_at )
			.setUpdatedAt( arguments.row.updated_at );
	}

	/* --------------------------------------------------------------- helpers */

	/**
	 * A stored answers document that will not parse is a corrupt row, not a
	 * reason to take the inbox down. It comes back empty and the submission
	 * still lists, with its date and sender, so somebody can see that it is
	 * there and go looking.
	 */
	private array function decodeAnswers( required string raw ){
		if ( !len( trim( arguments.raw ) ) || !isJSON( arguments.raw ) ) {
			return [];
		}

		var parsed = deserializeJSON( arguments.raw );

		return isArray( parsed ) ? parsed : [];
	}

	private struct function fieldRow( required forms.models.FormField field, required any stamp ){
		return {
			"site_id"      : arguments.field.getSiteId(),
			"form_id"      : arguments.field.getFormId(),
			"field_type"   : arguments.field.getFieldType(),
			"field_key"    : arguments.field.getFieldKey(),
			"label"        : arguments.field.getLabel(),
			"placeholder"  : arguments.field.getPlaceholder() ?: "",
			"help_text"    : arguments.field.getHelpText() ?: "",
			"options_text" : { value : arguments.field.getOptionsText() ?: "", cfsqltype : "cf_sql_longvarchar" },
			"is_required"  : flag( arguments.field.getIsRequired() ),
			"max_length"   : isNull( arguments.field.getMaxLength() )
				? { value : "", cfsqltype : "cf_sql_smallint", null : true }
				: { value : arguments.field.getMaxLength(), cfsqltype : "cf_sql_smallint", null : false },
			"sort_order"   : arguments.field.getSortOrder(),
			"created_at"   : { value : arguments.stamp, cfsqltype : "cf_sql_timestamp" },
			"updated_at"   : { value : arguments.stamp, cfsqltype : "cf_sql_timestamp" }
		};
	}

	private struct function flag( required boolean value ){
		return { value : arguments.value ? 1 : 0, cfsqltype : "cf_sql_tinyint", null : false };
	}

	private function formQuery(){
		return variables.query.from( variables.FORM_TABLE ).select( variables.FORM_COLS );
	}

	private function fieldQuery(){
		return variables.query.from( variables.FIELD_TABLE ).select( variables.FIELD_COLS );
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

}
