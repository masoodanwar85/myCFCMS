/**
 * Forms: building them, and receiving what people send.
 *
 * The counterpart to Contact. Contact owns a site's one enquiry form with fixed
 * fields; this owns forms whose fields an author defines. Splitting them keeps
 * the enquiry form from growing a builder it does not need, and keeps this from
 * inheriting Contact's fixed name/email/subject/message shape.
 *
 * Knows nothing of HTTP: no event, no request collection. Submitted values
 * arrive as a plain struct, which is what lets the same code serve the
 * shortcode, a future REST endpoint and a test.
 */
component singleton accessors="true" {

	property name="formRepository" inject="FormRepository@forms";
	property name="siteRepository" inject="SiteRepository@core";
	property name="fieldTypes"     inject="FieldTypes@forms";
	property name="slugifier"      inject="Slugifier@core";
	property name="sanitizer"      inject="ContentSanitizer@core";
	property name="mailService"    inject="MailService@core";
	property name="settings"       inject="coldbox:moduleSettings:forms";
	property name="wirebox"        inject="wirebox";
	property name="log"            inject="logbox:logger:{this}";

	variables.MAX_VALUE   = 10000;
	variables.MAX_SUMMARY = 255;

	/* ------------------------------------------------------------------ forms */

	/**
	 * @throws Forms.SiteNotFound
	 * @throws Forms.InvalidForm
	 * @throws Forms.SlugExists
	 */
	forms.models.Form function createForm(
		required numeric siteId,
		required string name,
		string slug             = "",
		string intro            = "",
		string submitLabel      = "",
		string successMessage   = "",
		string thankYouPath     = "",
		string recipientEmail   = "",
		boolean storeSubmissions = true
	){
		if ( isNull( siteRepository.findById( arguments.siteId ) ) ) {
			throw( type = "Forms.SiteNotFound", message = "No site with id [#arguments.siteId#]." );
		}

		var formName = trim( arguments.name );

		if ( !len( formName ) ) {
			throw( type = "Forms.InvalidForm", message = "A form requires a name." );
		}

		var formSlug = len( trim( arguments.slug ) ) ? slugify( arguments.slug ) : slugify( formName );

		if ( !len( formSlug ) ) {
			throw( type = "Forms.InvalidForm", message = "Could not derive a usable slug from [#formName#]." );
		}

		var built = wirebox
			.getInstance( "Form@forms" )
			.setSiteId( arguments.siteId )
			.setName( formName )
			.setSlug( formSlug )
			.setIntro( trim( arguments.intro ) )
			.setStoreSubmissions( arguments.storeSubmissions )
			.setRecipientEmail( requireUsableRecipient( arguments.recipientEmail ) )
			.setThankYouPath( safeReturnPath( arguments.thankYouPath ) );

		if ( len( trim( arguments.submitLabel ) ) ) {
			built.setSubmitLabel( trim( arguments.submitLabel ) );
		}
		if ( len( trim( arguments.successMessage ) ) ) {
			built.setSuccessMessage( trim( arguments.successMessage ) );
		}

		return formRepository.createForm( built );
	}

	forms.models.Form function updateForm(
		required numeric formId,
		string name,
		string intro,
		string submitLabel,
		string successMessage,
		string thankYouPath,
		string recipientEmail,
		boolean storeSubmissions,
		boolean isActive
	){
		var built = requireForm( arguments.formId );

		if ( !isNull( arguments.name ) ) {
			if ( !len( trim( arguments.name ) ) ) {
				throw( type = "Forms.InvalidForm", message = "A form requires a name." );
			}
			built.setName( trim( arguments.name ) );
		}
		if ( !isNull( arguments.intro ) ) {
			built.setIntro( trim( arguments.intro ) );
		}
		if ( !isNull( arguments.submitLabel ) && len( trim( arguments.submitLabel ) ) ) {
			built.setSubmitLabel( trim( arguments.submitLabel ) );
		}
		if ( !isNull( arguments.successMessage ) && len( trim( arguments.successMessage ) ) ) {
			built.setSuccessMessage( trim( arguments.successMessage ) );
		}
		if ( !isNull( arguments.thankYouPath ) ) {
			built.setThankYouPath( safeReturnPath( arguments.thankYouPath ) );
		}
		if ( !isNull( arguments.recipientEmail ) ) {
			built.setRecipientEmail( requireUsableRecipient( arguments.recipientEmail ) );
		}
		if ( !isNull( arguments.storeSubmissions ) ) {
			built.setStoreSubmissions( arguments.storeSubmissions );
		}
		if ( !isNull( arguments.isActive ) ) {
			built.setIsActive( arguments.isActive );
		}

		return formRepository.updateForm( built );
	}

	function deleteForm( required numeric formId ){
		requireForm( arguments.formId );
		formRepository.deleteForm( arguments.formId );

		return this;
	}

	function getFormById( required numeric formId ){
		return formRepository.findFormById( arguments.formId );
	}

	/**
	 * A form with its fields loaded, ready to render or validate against.
	 *
	 * @activeOnly What the public site always wants.
	 */
	function getFormBySlug(
		required numeric siteId,
		required string slug,
		boolean activeOnly = false
	){
		var found = formRepository.findFormBySlug(
			arguments.siteId,
			slugify( arguments.slug ),
			arguments.activeOnly
		);

		if ( isNull( found ) ) {
			return;
		}

		return withFields( found );
	}

	forms.models.Form function withFields( required forms.models.Form form ){
		arguments.form.setFields( formRepository.findFieldsForForm( arguments.form.getId() ) );

		return arguments.form;
	}

	array function getFormsForSite( required numeric siteId ){
		return formRepository.findFormsForSite( arguments.siteId );
	}

	numeric function countSubmissionsForForm( required numeric formId ){
		return formRepository.countSubmissionsForForm( arguments.formId );
	}

	/* ----------------------------------------------------------------- fields */

	/**
	 * @throws Forms.FormNotFound
	 * @throws Forms.InvalidField
	 * @throws Forms.FieldKeyExists
	 */
	forms.models.FormField function addField(
		required numeric formId,
		required string fieldType,
		required string label,
		string fieldKey    = "",
		string placeholder = "",
		string helpText    = "",
		string optionsText = "",
		boolean isRequired = false,
		numeric maxLength
	){
		var parent = requireForm( arguments.formId );
		var type   = lCase( trim( arguments.fieldType ) );

		if ( !fieldTypes.isValid( type ) ) {
			throw( type = "Forms.InvalidField", message = "[#arguments.fieldType#] is not a kind of field." );
		}

		var text = trim( arguments.label );

		if ( !len( text ) ) {
			throw( type = "Forms.InvalidField", message = "A field requires a label." );
		}

		var key = len( trim( arguments.fieldKey ) ) ? keyify( arguments.fieldKey ) : keyify( text );

		if ( !len( key ) ) {
			throw( type = "Forms.InvalidField", message = "Could not derive a usable field name from [#text#]." );
		}

		var built = wirebox
			.getInstance( "FormField@forms" )
			.setSiteId( parent.getSiteId() )
			.setFormId( parent.getId() )
			.setFieldType( type )
			.setFieldKey( key )
			.setLabel( text )
			.setPlaceholder( trim( arguments.placeholder ) )
			.setHelpText( trim( arguments.helpText ) )
			.setOptionsText( requireOptions( type, arguments.optionsText ) )
			.setIsRequired( arguments.isRequired )
			.setSortOrder( formRepository.nextSortOrder( parent.getId() ) );

		if ( !isNull( arguments.maxLength ) && val( arguments.maxLength ) > 0 ) {
			built.setMaxLength( min( variables.MAX_VALUE, val( arguments.maxLength ) ) );
		}

		return formRepository.createField( built );
	}

	/**
	 * Change a field.
	 *
	 * `fieldKey` is deliberately absent. Answers are stored under it, and
	 * renaming it would leave every response already given filed under a name
	 * the form no longer has. The label is what an author actually wants to
	 * change, and that is free.
	 */
	forms.models.FormField function updateField(
		required numeric fieldId,
		string fieldType,
		string label,
		string placeholder,
		string helpText,
		string optionsText,
		boolean isRequired,
		numeric maxLength,
		numeric sortOrder
	){
		var field = requireField( arguments.fieldId );

		if ( !isNull( arguments.fieldType ) ) {
			var type = lCase( trim( arguments.fieldType ) );

			if ( !fieldTypes.isValid( type ) ) {
				throw( type = "Forms.InvalidField", message = "[#arguments.fieldType#] is not a kind of field." );
			}

			field.setFieldType( type );
		}

		if ( !isNull( arguments.label ) ) {
			if ( !len( trim( arguments.label ) ) ) {
				throw( type = "Forms.InvalidField", message = "A field requires a label." );
			}
			field.setLabel( trim( arguments.label ) );
		}
		if ( !isNull( arguments.placeholder ) ) {
			field.setPlaceholder( trim( arguments.placeholder ) );
		}
		if ( !isNull( arguments.helpText ) ) {
			field.setHelpText( trim( arguments.helpText ) );
		}
		if ( !isNull( arguments.isRequired ) ) {
			field.setIsRequired( arguments.isRequired );
		}
		if ( !isNull( arguments.sortOrder ) ) {
			field.setSortOrder( val( arguments.sortOrder ) );
		}
		if ( !isNull( arguments.maxLength ) ) {
			field.setMaxLength( val( arguments.maxLength ) > 0 ? min( variables.MAX_VALUE, val( arguments.maxLength ) ) : javacast( "null", "" ) );
		}

		// Checked against the type it will have after this call, not the one it
		// had before — a field changed from text to select needs its options.
		if ( !isNull( arguments.optionsText ) ) {
			field.setOptionsText( requireOptions( field.getFieldType(), arguments.optionsText ) );
		} else {
			field.setOptionsText( requireOptions( field.getFieldType(), field.getOptionsText() ?: "" ) );
		}

		return formRepository.updateField( field );
	}

	function deleteField( required numeric fieldId ){
		requireField( arguments.fieldId );
		formRepository.deleteField( arguments.fieldId );

		return this;
	}

	array function getFieldsForForm( required numeric formId ){
		return formRepository.findFieldsForForm( arguments.formId );
	}

	function getFieldById( required numeric fieldId ){
		return formRepository.findFieldById( arguments.fieldId );
	}

	/* ------------------------------------------------------------ submissions */

	/**
	 * Check a response without storing it, so the form can be redisplayed with
	 * its errors and so validation is testable without writing rows.
	 *
	 * @return An array of messages written for a visitor, not a log.
	 */
	array function validateSubmission( required forms.models.Form form, required struct values ){
		var errors = [];

		for ( var field in arguments.form.getFields() ) {
			var given = readValue( field, arguments.values );
			var shown = field.getLabel();

			if ( !len( given ) ) {
				if ( field.getIsRequired() ) {
					arrayAppend( errors, "Please complete #shown#." );
				}

				// Nothing further to check about an answer that is not there.
				continue;
			}

			var cap = isNull( field.getMaxLength() ) ? variables.MAX_VALUE : field.getMaxLength();

			if ( len( given ) > cap ) {
				arrayAppend( errors, "#shown# is too long." );
				continue;
			}

			switch ( field.getFieldType() ) {
				case "email":
					if ( !isValid( "email", given ) ) {
						arrayAppend( errors, "#shown# does not look like an email address." );
					}
					break;

				case "number":
					if ( !isNumeric( given ) ) {
						arrayAppend( errors, "#shown# must be a number." );
					}
					break;

				case "date":
					if ( !isDate( given ) ) {
						arrayAppend( errors, "#shown# must be a date." );
					}
					break;

				case "select":
				case "radio":
				case "checkbox":
					// An answer the form never offered did not come from the
					// form. Checked rather than trusted: the options are in the
					// page source and a posted value is whatever the sender says.
					for ( var chosen in chosenValues( field, arguments.values ) ) {
						if ( !arrayContains( field.getOptions(), chosen ) ) {
							arrayAppend( errors, "#shown# has an answer that is not one of the choices." );
							break;
						}
					}
					break;
			}
		}

		return errors;
	}

	/**
	 * Record a response and notify whoever the form delivers to.
	 *
	 * @throws Forms.FormInactive
	 * @throws Forms.InvalidSubmission
	 * @throws Forms.TooManySubmissions
	 */
	function submit(
		required forms.models.Form form,
		required struct values,
		string ipAddress = "",
		string userAgent = ""
	){
		if ( !arguments.form.getIsActive() ) {
			throw( type = "Forms.FormInactive", message = "This form is not accepting responses." );
		}

		var errors = validateSubmission( arguments.form, arguments.values );

		if ( errors.len() ) {
			throw(
				type    = "Forms.InvalidSubmission",
				message = errors[ 1 ],
				detail  = arrayToList( errors, " " )
			);
		}

		guardRate( arguments.form.getSiteId(), arguments.ipAddress );

		var answers = buildAnswers( arguments.form, arguments.values );

		var submission = wirebox
			.getInstance( "FormSubmission@forms" )
			.setSiteId( arguments.form.getSiteId() )
			.setFormId( arguments.form.getId() )
			.setAnswers( answers )
			.setSenderEmail( senderFrom( arguments.form, answers ) )
			.setSummary( summaryFrom( answers ) )
			.setIpAddress( left( arguments.ipAddress, 45 ) )
			.setUserAgent( arguments.userAgent );

		// A form may deliberately keep nothing. It is still validated, still
		// rate limited and still delivered by email — it simply leaves no row.
		var stored = arguments.form.getStoreSubmissions()
			? formRepository.createSubmission( submission )
			: submission;

		notifyRecipient( arguments.form, stored );

		return stored;
	}

	array function getSubmissions(
		required numeric siteId,
		string status  = "",
		numeric formId = 0,
		numeric limit  = 25,
		numeric offset = 0
	){
		return formRepository.findSubmissionsForSite(
			arguments.siteId,
			arguments.status,
			arguments.formId,
			arguments.limit,
			arguments.offset
		);
	}

	numeric function countSubmissions( required numeric siteId, string status = "", numeric formId = 0 ){
		return formRepository.countSubmissionsForSite( arguments.siteId, arguments.status, arguments.formId );
	}

	function getSubmissionById( required numeric submissionId ){
		return formRepository.findSubmissionById( arguments.submissionId );
	}

	function markSubmission( required numeric submissionId, required string status ){
		if ( !listFindNoCase( "new,read,spam", arguments.status ) ) {
			throw( type = "Forms.InvalidStatus", message = "[#arguments.status#] is not a response status." );
		}

		formRepository.updateSubmissionStatus( arguments.submissionId, lCase( arguments.status ) );

		return this;
	}

	function deleteSubmission( required numeric submissionId ){
		formRepository.deleteSubmission( arguments.submissionId );

		return this;
	}

	/* --------------------------------------------------------------- helpers */

	/**
	 * A path we are willing to redirect a visitor to.
	 *
	 * Site-relative only, exactly as Contact does it. An open redirect on a
	 * public form is how a phishing page borrows a client's domain.
	 */
	string function safeReturnPath( required string path ){
		var candidate = trim( arguments.path );

		if ( !len( candidate ) || len( candidate ) > 500 ) {
			return "";
		}

		if ( !reFind( "^/[^/]", candidate ) ) {
			return "";
		}

		if ( reFind( "[[:cntrl:]]", candidate ) ) {
			return "";
		}

		return candidate;
	}

	/**
	 * A field name: lowercase, letters, digits and underscores.
	 *
	 * Not the slugifier: this ends up as an HTML `name` attribute and as a key
	 * in a JSON document, and a hyphen in either is legal but awkward in both.
	 */
	string function keyify( required string value ){
		var key = lCase( trim( arguments.value ) );

		key = reReplace( key, "[^a-z0-9]+", "_", "all" );
		key = reReplace( key, "^_+|_+$", "", "all" );

		return left( key, 64 );
	}

	/* ------------------------------------------------------------- internals */

	/**
	 * The answers document: what was asked, beside what was said.
	 *
	 * Labels are copied in rather than referenced, so a response stays readable
	 * after the form is rewritten. See the migration for the full reasoning.
	 */
	private array function buildAnswers( required forms.models.Form form, required struct values ){
		var answers = [];

		for ( var field in arguments.form.getFields() ) {
			var entry = {
				"key"   : field.getFieldKey(),
				"label" : field.getLabel(),
				"type"  : field.getFieldType()
			};

			if ( fieldTypes.isMultiValue( field.getFieldType() ) ) {
				entry[ "value" ] = chosenValues( field, arguments.values );
			} else {
				// Sanitised on the way in, unlike page content: nothing here is
				// meant to be markup, and an answer is displayed in the admin
				// and in an email that a person opens.
				entry[ "value" ] = left(
					sanitizer.sanitize( readValue( field, arguments.values ), false ),
					variables.MAX_VALUE
				);
			}

			arrayAppend( answers, entry );
		}

		return answers;
	}

	/**
	 * One posted value as text, whatever shape it arrived in.
	 *
	 * A checkbox group posts a list; everything else posts a string. Reading
	 * both here means no caller has to know which types can hold several.
	 */
	private string function readValue( required forms.models.FormField field, required struct values ){
		var key = arguments.field.getFieldKey();

		if ( !structKeyExists( arguments.values, key ) ) {
			return "";
		}

		var raw = arguments.values[ key ];

		if ( isArray( raw ) ) {
			return arrayToList( raw, ", " );
		}

		return trim( toString( raw ) );
	}

	private array function chosenValues( required forms.models.FormField field, required struct values ){
		var key = arguments.field.getFieldKey();

		if ( !structKeyExists( arguments.values, key ) ) {
			return [];
		}

		var raw = arguments.values[ key ];

		if ( isArray( raw ) ) {
			return raw.map( ( v ) => trim( toString( v ) ) );
		}

		// A multi-value field posts a comma list when several boxes are ticked.
		return listToArray( toString( raw ), ",", false ).map( ( v ) => trim( v ) );
	}

	private string function senderFrom( required forms.models.Form form, required array answers ){
		var emailField = arguments.form.emailField();

		if ( isNull( emailField ) ) {
			return "";
		}

		for ( var answer in arguments.answers ) {
			if ( answer.key == emailField.getFieldKey() ) {
				return lCase( left( toString( answer.value ), 191 ) );
			}
		}

		return "";
	}

	/**
	 * A line for the inbox list: the first answer that is neither the sender's
	 * address nor empty, because "which form" and "who from" are already
	 * columns of their own.
	 */
	private string function summaryFrom( required array answers ){
		for ( var answer in arguments.answers ) {
			if ( answer.type == "email" ) {
				continue;
			}

			var value = isArray( answer.value ) ? arrayToList( answer.value, ", " ) : toString( answer.value );

			if ( len( trim( value ) ) ) {
				return left( trim( value ), variables.MAX_SUMMARY );
			}
		}

		return "";
	}

	private function guardRate( required numeric siteId, required string ipAddress ){
		var perHour = val( settings.maxPerHourPerAddress ?: 0 );

		if ( !perHour || !len( trim( arguments.ipAddress ) ) ) {
			return this;
		}

		var since = dateAdd( "h", -1, now() );
		var sent  = formRepository.countRecentFrom( arguments.siteId, arguments.ipAddress, since );

		if ( sent >= perHour ) {
			throw(
				type    = "Forms.TooManySubmissions",
				message = "Too many responses from this address. Please try again later."
			);
		}

		return this;
	}

	private function notifyRecipient( required forms.models.Form form, required any submission ){
		var recipient = arguments.form.getRecipientEmail() ?: "";

		if ( !len( recipient ) || !( settings.sendNotifications ?: false ) ) {
			return this;
		}

		try {
			var args = {
				to       : recipient,
				// The site's own address, not the sender's: sending as the
				// visitor fails SPF and gets the site's mail marked as spam.
				// The reply-to below is what makes "reply" reach them.
				from     : recipient,
				subject  : arguments.form.getName() & ": new response",
				template : "emails/formNotification",
				data     : {
					"formName" : arguments.form.getName(),
					"answers"  : arguments.submission.getAnswers()
				},
				siteId   : arguments.form.getSiteId()
			};

			// Only when the form asked for one. Setting an empty reply-to is
			// worse than setting none.
			if ( len( arguments.submission.getSenderEmail() ?: "" ) ) {
				args.replyTo = arguments.submission.getSenderEmail();
			}

			mailService.send( argumentCollection = args );
		} catch ( any e ) {
			// Already recorded inside MailService; a form must not refuse a
			// visitor's response because SMTP is down.
			log.error( "Form notification for [#arguments.form.getSlug()#] failed: #e.message#", e );
		}

		return this;
	}

	private string function requireUsableRecipient( required string email ){
		var address = lCase( trim( arguments.email ) );

		if ( len( address ) && !isValid( "email", address ) ) {
			throw( type = "Forms.InvalidForm", message = "[#arguments.email#] is not a usable email address." );
		}

		return address;
	}

	/**
	 * A choice field with no options is a control a visitor cannot answer, and
	 * a required one would make the form impossible to submit.
	 */
	private string function requireOptions( required string type, required string optionsText ){
		if ( !fieldTypes.hasOptions( arguments.type ) ) {
			return "";
		}

		var text = trim( arguments.optionsText );

		if ( !len( text ) ) {
			throw(
				type    = "Forms.InvalidField",
				message = "A #fieldTypes.labelFor( arguments.type )# field needs at least one choice, one per line."
			);
		}

		return text;
	}

	private string function slugify( required string value ){
		return slugifier.slugify( arguments.value );
	}

	private forms.models.Form function requireForm( required numeric formId ){
		var found = formRepository.findFormById( arguments.formId );

		if ( isNull( found ) ) {
			throw( type = "Forms.FormNotFound", message = "No form with id [#arguments.formId#]." );
		}

		return found;
	}

	private forms.models.FormField function requireField( required numeric fieldId ){
		var found = formRepository.findFieldById( arguments.fieldId );

		if ( isNull( found ) ) {
			throw( type = "Forms.FieldNotFound", message = "No field with id [#arguments.fieldId#]." );
		}

		return found;
	}

}
