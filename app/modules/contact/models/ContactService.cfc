/**
 * Contact form use cases.
 *
 * Unlike every other service so far, `submit()` is reachable by anyone on the
 * internet. Everything it does assumes the caller is hostile until proven
 * otherwise: values are validated and length-capped, the message is stored as
 * text and never as markup, and repeated submissions from one address are
 * throttled.
 */
component singleton accessors="true" {

	property name="contactRepository" inject="ContactRepository@contact";
	property name="slugifier"        inject="Slugifier@core";
	property name="siteRepository"    inject="SiteRepository@core";
	property name="settings"          inject="coldbox:moduleSettings:contact";
	property name="wirebox"           inject="wirebox";
	property name="mailService"       inject="MailService@core";
	property name="log"               inject="logbox:logger:{this}";

	// Caps, so a submission cannot be used to fill the database.
	variables.MAX_NAME    = 150;
	variables.MAX_EMAIL   = 191;
	variables.MAX_SUBJECT = 255;
	variables.MAX_MESSAGE = 10000;

	/* ------------------------------------------------------------------ forms */

	/**
	 * @throws Contact.SiteNotFound
	 * @throws Contact.InvalidForm
	 * @throws Contact.FormSlugExists
	 */
	contact.models.ContactForm function createForm(
		required numeric siteId,
		required string name,
		string slug           = "",
		string intro          = "",
		string recipientEmail = "",
		string successMessage = ""
	){
		if ( isNull( siteRepository.findById( arguments.siteId ) ) ) {
			throw( type = "Contact.SiteNotFound", message = "No site with id [#arguments.siteId#]." );
		}

		var formName = trim( arguments.name );

		if ( !len( formName ) ) {
			throw( type = "Contact.InvalidForm", message = "A form requires a name." );
		}

		var formSlug = len( trim( arguments.slug ) ) ? slugify( arguments.slug ) : slugify( formName );

		if ( !len( formSlug ) ) {
			throw( type = "Contact.InvalidForm", message = "Could not derive a usable slug from [#formName#]." );
		}

		if ( len( trim( arguments.recipientEmail ) ) && !isValidEmail( trim( arguments.recipientEmail ) ) ) {
			throw( type = "Contact.InvalidForm", message = "[#arguments.recipientEmail#] is not a usable email address." );
		}

		if ( !isNull( contactRepository.findFormBySlug( arguments.siteId, formSlug ) ) ) {
			throw( type = "Contact.FormSlugExists", message = "This site already has a form at [#formSlug#]." );
		}

		var contactForm = wirebox
			.getInstance( "ContactForm@contact" )
			.setSiteId( arguments.siteId )
			.setName( formName )
			.setSlug( formSlug )
			.setIntro( trim( arguments.intro ) )
			.setRecipientEmail( lCase( trim( arguments.recipientEmail ) ) );

		if ( len( trim( arguments.successMessage ) ) ) {
			contactForm.setSuccessMessage( trim( arguments.successMessage ) );
		}

		return contactRepository.createForm( contactForm );
	}

	contact.models.ContactForm function updateForm(
		required numeric formId,
		string name,
		string intro,
		string recipientEmail,
		string successMessage,
		boolean isActive
	){
		var contactForm = requireForm( arguments.formId );

		if ( !isNull( arguments.name ) ) {
			if ( !len( trim( arguments.name ) ) ) {
				throw( type = "Contact.InvalidForm", message = "A form requires a name." );
			}
			contactForm.setName( trim( arguments.name ) );
		}
		if ( !isNull( arguments.intro ) ) {
			contactForm.setIntro( trim( arguments.intro ) );
		}
		if ( !isNull( arguments.recipientEmail ) ) {
			var recipient = lCase( trim( arguments.recipientEmail ) );

			if ( len( recipient ) && !isValidEmail( recipient ) ) {
				throw( type = "Contact.InvalidForm", message = "[#recipient#] is not a usable email address." );
			}

			contactForm.setRecipientEmail( recipient );
		}
		if ( !isNull( arguments.successMessage ) && len( trim( arguments.successMessage ) ) ) {
			contactForm.setSuccessMessage( trim( arguments.successMessage ) );
		}
		if ( !isNull( arguments.isActive ) ) {
			contactForm.setIsActive( arguments.isActive );
		}

		return contactRepository.updateForm( contactForm );
	}

	function deleteForm( required numeric formId ){
		requireForm( arguments.formId );
		contactRepository.deleteForm( arguments.formId );
		return this;
	}

	function getFormById( required numeric formId ){
		return contactRepository.findFormById( arguments.formId );
	}

	function getFormBySlug( required numeric siteId, required string slug ){
		return contactRepository.findFormBySlug( arguments.siteId, slugify( arguments.slug ) );
	}

	array function getFormsForSite( required numeric siteId ){
		return contactRepository.findFormsForSite( arguments.siteId );
	}

	/**
	 * The form a site's `/contact` URL should show: its first active one.
	 */
	function getDefaultForm( required numeric siteId ){
		var active = contactRepository
			.findFormsForSite( arguments.siteId )
			.filter( ( candidate ) => candidate.getIsActive() );

		// An explicit return, not a ternary: a ternary cannot yield null on
		// ColdFusion — it hands back an empty string, which `isNull()` then
		// reports as present.
		if ( active.len() ) {
			return active[ 1 ];
		}

		return;
	}

	/* ------------------------------------------------------------ submissions */

	/**
	 * Validate a submission without storing it.
	 *
	 * Separated so the form can be redisplayed with errors, and so validation
	 * is testable without writing rows.
	 *
	 * @return An array of human-readable messages. Empty means acceptable.
	 */
	array function validateSubmission( required struct values ){
		var errors = [];
		var name    = trim( arguments.values.name ?: "" );
		var email   = trim( arguments.values.email ?: "" );
		var message = trim( arguments.values.message ?: "" );

		if ( !len( name ) ) {
			errors.append( "Please give your name." );
		} else if ( len( name ) > variables.MAX_NAME ) {
			errors.append( "That name is too long." );
		}

		if ( !len( email ) ) {
			errors.append( "Please give an email address." );
		} else if ( !isValidEmail( email ) || len( email ) > variables.MAX_EMAIL ) {
			errors.append( "That email address does not look right." );
		}

		if ( !len( message ) ) {
			errors.append( "Please write a message." );
		} else if ( len( message ) > variables.MAX_MESSAGE ) {
			errors.append( "That message is too long." );
		}

		if ( len( trim( arguments.values.subject ?: "" ) ) > variables.MAX_SUBJECT ) {
			errors.append( "That subject is too long." );
		}

		return errors;
	}

	/**
	 * Store a message sent through a form.
	 *
	 * @form      The form it was sent through.
	 * @values    Submitted values: name, email, subject, message.
	 * @ipAddress Sender's address, for tracing abuse.
	 * @userAgent Sender's user agent.
	 *
	 * @throws Contact.FormInactive
	 * @throws Contact.InvalidSubmission
	 * @throws Contact.TooManySubmissions
	 */
	contact.models.Submission function submit(
		required contact.models.ContactForm form,
		required struct values,
		string ipAddress = "",
		string userAgent = ""
	){
		if ( !arguments.form.getIsActive() ) {
			throw( type = "Contact.FormInactive", message = "This form is not accepting messages." );
		}

		var errors = validateSubmission( arguments.values );

		if ( errors.len() ) {
			throw(
				type    = "Contact.InvalidSubmission",
				message = errors[ 1 ],
				detail  = errors.toList( " " )
			);
		}

		guardRate( arguments.form.getSiteId(), arguments.ipAddress );

		var submission = wirebox
			.getInstance( "Submission@contact" )
			.setSiteId( arguments.form.getSiteId() )
			.setFormId( arguments.form.getId() )
			.setName( left( trim( arguments.values.name ), variables.MAX_NAME ) )
			.setEmail( lCase( left( trim( arguments.values.email ), variables.MAX_EMAIL ) ) )
			.setSubject( left( trim( arguments.values.subject ?: "" ), variables.MAX_SUBJECT ) )
			.setMessage( left( trim( arguments.values.message ), variables.MAX_MESSAGE ) )
			.setIpAddress( left( arguments.ipAddress, 45 ) )
			.setUserAgent( arguments.userAgent );

		var stored = contactRepository.createSubmission( submission );

		notifyRecipient( arguments.form, stored );

		return stored;
	}

	array function getSubmissions(
		required numeric siteId,
		string status  = "",
		numeric limit  = 25,
		numeric offset = 0
	){
		return contactRepository.findSubmissionsForSite(
			arguments.siteId,
			arguments.status,
			arguments.limit,
			arguments.offset
		);
	}

	numeric function countSubmissions( required numeric siteId, string status = "" ){
		return contactRepository.countSubmissionsForSite( arguments.siteId, arguments.status );
	}

	function getSubmissionById( required numeric submissionId ){
		return contactRepository.findSubmissionById( arguments.submissionId );
	}

	numeric function countNew( required numeric siteId ){
		return contactRepository.countByStatus( arguments.siteId, "new" );
	}

	/**
	 * @throws Contact.InvalidStatus
	 */
	function setStatus( required numeric submissionId, required string status ){
		if ( ![ "new", "read", "spam" ].findNoCase( arguments.status ) ) {
			throw( type = "Contact.InvalidStatus", message = "Unknown status [#arguments.status#]." );
		}

		contactRepository.updateSubmissionStatus( arguments.submissionId, lCase( arguments.status ) );

		return this;
	}

	function deleteSubmission( required numeric submissionId ){
		contactRepository.deleteSubmission( arguments.submissionId );
		return this;
	}

	/* ---------------------------------------------------------------- helpers */

	boolean function isValidEmail( required string email ){
		return reFind( "^[^@\s]+@[^@\s.]+(\.[^@\s.]+)+$", arguments.email ) > 0;
	}

	string function slugify( required string value ){
		// Delegated: five copies of this each dropped accented
		// characters instead of transliterating them.
		return slugifier.slugify( arguments.value );
	}

	/**
	 * Refuse a flood from one address.
	 *
	 * Counts what that address already sent rather than keeping any state of
	 * its own, so it survives a restart and needs no extra store. Crude, and
	 * useless against a distributed flood — a real rate limiter belongs at the
	 * edge — but it stops the obvious case.
	 */
	private function guardRate( required numeric siteId, required string ipAddress ){
		var maxPerHour = val( settings.maxPerHourPerAddress ?: 5 );

		if ( !maxPerHour || !len( arguments.ipAddress ) ) {
			return this;
		}

		var recent = contactRepository.countRecentFrom(
			arguments.siteId,
			arguments.ipAddress,
			dateAdd( "h", -1, now() )
		);

		if ( recent >= maxPerHour ) {
			log.warn( "Contact throttle hit for [#arguments.ipAddress#] on site [#arguments.siteId#]." );
			throw(
				type    = "Contact.TooManySubmissions",
				message = "You have sent several messages already. Please try again later."
			);
		}

		return this;
	}

	/**
	 * Email the site's recipient that something arrived.
	 *
	 * Named `notifyRecipient`, not `notify`: ColdFusion has a built-in `notify()`
	 * and a component method of that name collides with it.
	 *
	 * Still deliberately best-effort. MailService records every attempt and
	 * never throws on a delivery failure, so a visitor's message is never
	 * rejected because the mail server is down — it is already stored and
	 * visible in the admin regardless.
	 */
	private function notifyRecipient(
		required contact.models.ContactForm form,
		required contact.models.Submission submission
	){
		var recipient = arguments.form.getRecipientEmail() ?: "";

		if ( !len( recipient ) || !( settings.sendNotifications ?: false ) ) {
			return this;
		}

		try {
			mailService.send(
				to      = recipient,
				// The site's own address, not the visitor's: sending as the
				// visitor fails SPF and gets the site's mail marked as spam.
				// The reply-to is what makes "reply" reach them.
				from    = recipient,
				replyTo = arguments.submission.getEmail(),
				subject = "Enquiry: " & (
					len( arguments.submission.getSubject() )
						? arguments.submission.getSubject()
						: "no subject"
				),
				template = "emails/contactNotification",
				data     = {
					"formName" : arguments.form.getName(),
					"name"     : arguments.submission.getName(),
					"email"    : arguments.submission.getEmail(),
					"subject"  : arguments.submission.getSubject() ?: "",
					"message"  : arguments.submission.getMessage()
				},
				siteId = arguments.form.getSiteId()
			);
		} catch ( any e ) {
			// Recording already happened inside MailService; this only catches
			// something unexpected on the way in.
			log.error( "Contact notification to [#recipient#] failed: #e.message#" );
		}

		return this;
	}

	private function requireForm( required numeric formId ){
		var contactForm = contactRepository.findFormById( arguments.formId );

		if ( isNull( contactForm ) ) {
			throw( type = "Contact.FormNotFound", message = "No form with id [#arguments.formId#]." );
		}

		return contactForm;
	}

}
