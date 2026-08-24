/**
 * Sending email.
 *
 * The one thing this must never do is lose a message quietly. Everything the
 * CMS wants to send is written to `mail_messages` first and only then handed to
 * the mail server, so a delivery failure leaves evidence rather than silence.
 *
 * Three modes, chosen by the `mail.mode` setting:
 *
 *   `off`   record the message and stop. The default, because no SMTP is
 *           configured yet and pretending otherwise would fail on every send.
 *   `log`   record it and write the body to the log, so a developer can read
 *           what a client would have received.
 *   `send`  record it and actually deliver it.
 *
 * A caller never checks the mode. It asks for a message to be sent and gets a
 * record back; whether that record says `sent` or `suppressed` is a deployment
 * question, not a calling-code question.
 */
component singleton extends="core.models.persistence.BaseRepository" {

	property name="settings"      inject="coldbox:moduleSettings:core";
	property name="tenantContext" inject="TenantContext@core";
	property name="renderer"      inject="provider:coldbox:renderer";
	property name="log"           inject="logbox:logger:{this}";

	variables.TABLE = "mail_messages";

	/**
	 * Send a message.
	 *
	 * @to        Recipient address.
	 * @subject   Subject line.
	 * @body      Message body. Ignored when `template` is given.
	 * @template  A view to render instead, e.g. "emails/contactNotification".
	 * @data      Values passed to that view as `args`.
	 * @from      Sender. Defaults to the configured platform address.
	 * @replyTo   Where a reply should go, when that differs from the sender.
	 * @type      `html` or `text`.
	 * @siteId    Tenant this belongs to. Defaults to the current one, if any.
	 *
	 * @throws Mail.InvalidRecipient
	 *
	 * @return The stored record, including its final status.
	 */
	struct function send(
		required string to,
		required string subject,
		string body     = "",
		string template = "",
		struct data     = {},
		string from     = "",
		string replyTo  = "",
		string type     = "html",
		numeric siteId
	){
		var recipient = lCase( trim( arguments.to ) );

		if ( !isValidAddress( recipient ) ) {
			throw(
				type    = "Mail.InvalidRecipient",
				message = "[#arguments.to#] is not a usable email address."
			);
		}

		var sender  = len( trim( arguments.from ) ) ? lCase( trim( arguments.from ) ) : defaultFrom();
		var content = len( arguments.template )
			? renderTemplate( arguments.template, arguments.data )
			: arguments.body;

		var record = {
			"to"       : recipient,
			"from"     : sender,
			"replyTo"  : lCase( trim( arguments.replyTo ) ),
			"subject"  : left( trim( arguments.subject ), 255 ),
			"body"     : content,
			"type"     : arguments.type == "text" ? "text" : "html",
			"status"   : "queued"
		};

		// Set separately rather than in the literal above: putting a null into
		// a struct literal simply omits the key on ColdFusion, and the absence
		// then reads as a missing element rather than "no tenant".
		if ( !isNull( arguments.siteId ) ) {
			record.siteId = arguments.siteId;
		} else if ( tenantContext.hasCurrentTenant() ) {
			record.siteId = tenantContext.getCurrentTenantId();
		}

		// Written before any attempt, so a message cannot be lost between
		// deciding to send it and failing to.
		record.id = store( record );

		return deliver( record );
	}

	/**
	 * What the CMS has tried to send for a site, newest first.
	 */
	array function getMessages(
		required numeric siteId,
		string status  = "",
		numeric limit  = 25,
		numeric offset = 0
	){
		var q = variables.query
			.from( variables.TABLE )
			.select( [ "id", "to_address", "subject", "status", "error", "sent_at", "created_at" ] )
			.where( "site_id", arguments.siteId );

		if ( len( arguments.status ) ) {
			q.where( "status", arguments.status );
		}

		return q
			.orderBy( "created_at", "desc" )
			.orderBy( "id", "desc" )
			.limit( arguments.limit )
			.offset( arguments.offset )
			.get();
	}

	numeric function countMessages( required numeric siteId, string status = "" ){
		var q = variables.query.from( variables.TABLE ).where( "site_id", arguments.siteId );

		if ( len( arguments.status ) ) {
			q.where( "status", arguments.status );
		}

		return q.count();
	}

	function getMessageById( required numeric id ){
		var row = variables.query.from( variables.TABLE ).where( "id", arguments.id ).first();

		if ( row.isEmpty() ) {
			return;
		}

		return row;
	}

	/* ---------------------------------------------------------------- config */

	string function getMode(){
		var mode = lCase( trim( settings.mailMode ?: "off" ) );

		return listFindNoCase( "off,log,send", mode ) ? mode : "off";
	}

	boolean function isEnabled(){
		return getMode() == "send";
	}

	string function defaultFrom(){
		return lCase( trim( settings.mailFrom ?: "no-reply@localhost" ) );
	}

	boolean function isValidAddress( required string address ){
		return reFind( "^[^@\s]+@[^@\s.]+(\.[^@\s.]+)+$", arguments.address ) > 0;
	}

	/* --------------------------------------------------------------- internal */

	private struct function deliver( required struct record ){
		var mode = getMode();

		if ( mode == "off" ) {
			markStatus( arguments.record.id, "suppressed", "Mail is switched off (core setting `mailMode`)." );
			arguments.record.status = "suppressed";
			return arguments.record;
		}

		if ( mode == "log" ) {
			log.info(
				"MAIL (not sent) to=#arguments.record.to# subject=#arguments.record.subject#"
				& chr( 10 ) & arguments.record.body
			);
			markStatus( arguments.record.id, "suppressed", "Logged only (core setting `mailMode` is `log`)." );
			arguments.record.status = "suppressed";
			return arguments.record;
		}

		try {
			var args = {
				to      : arguments.record.to,
				from    : arguments.record.from,
				subject : arguments.record.subject,
				type    : arguments.record.type
			};

			if ( len( arguments.record.replyTo ) ) {
				args.replyTo = arguments.record.replyTo;
			}

			sendViaServer( args, arguments.record.body );

			markStatus( arguments.record.id, "sent" );
			arguments.record.status = "sent";
		} catch ( any e ) {
			// The message is already recorded, so a failure here loses nothing
			// but the delivery. Callers are not asked to handle it: a contact
			// form should not reject a visitor's message because SMTP is down.
			log.error( "Mail to [#arguments.record.to#] failed: #e.message#" );
			markStatus( arguments.record.id, "failed", e.message );
			arguments.record.status = "failed";
			arguments.record.error  = e.message;
		}

		return arguments.record;
	}

	/**
	 * Isolated so a test can replace delivery without a mail server.
	 */
	private function sendViaServer( required struct args, required string body ){
		var payload = arguments.body;

		mail( argumentCollection = arguments.args ){
			writeOutput( payload );
		}

		return this;
	}

	private numeric function store( required struct record ){
		var result = variables.query
			.from( variables.TABLE )
			.insert( {
				"site_id"      : structKeyExists( arguments.record, "siteId" )
					? nullableId( arguments.record.siteId )
					: nullableId(),
				"to_address"   : arguments.record.to,
				"from_address" : arguments.record.from,
				"reply_to"     : arguments.record.replyTo,
				"subject"      : arguments.record.subject,
				"body"         : { value : arguments.record.body, cfsqltype : "cf_sql_longvarchar" },
				"content_type" : arguments.record.type,
				"status"       : "queued",
				"created_at"   : { value : now(), cfsqltype : "cf_sql_timestamp" }
			} );

		return generatedKey( result, variables.TABLE );
	}

	private function markStatus( required numeric id, required string status, string error = "" ){
		variables.query
			.from( variables.TABLE )
			.where( "id", arguments.id )
			.update( {
				"status"  : arguments.status,
				"error"   : left( arguments.error, 500 ),
				"sent_at" : arguments.status == "sent"
					? { value : now(), cfsqltype : "cf_sql_timestamp" }
					: { value : "", cfsqltype : "cf_sql_timestamp", null : true }
			} );

		return this;
	}

	private string function renderTemplate( required string template, required struct data ){
		return renderer.view( view = arguments.template, args = arguments.data, module = "core" );
	}

	private struct function nullableId( value ){
		return {
			value     : isNull( arguments.value ) ? "" : arguments.value,
			cfsqltype : "cf_sql_bigint",
			null      : isNull( arguments.value )
		};
	}

}
