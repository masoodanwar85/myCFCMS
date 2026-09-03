<cfsetting showdebugoutput="false" requesttimeout="120">
<cfcontent type="text/plain">
<cfscript>
/**
 * Find out why an email did not arrive.
 *
 * There are three independent places a notification can stop, and from the
 * outside all three look identical: nothing arrives. Worse, two of them are
 * *silent by design* — a suppressed message is not an error, and a module that
 * decides not to notify never calls the mail layer at all.
 *
 *   1. The module gate.  `contact.sendNotifications` / `forms.sendNotifications`
 *      default to false. `notifyRecipient()` returns before queueing anything,
 *      so `mail_messages` gains no row. Nothing is logged, because nothing went
 *      wrong.
 *
 *   2. The mail mode.  `core.mailMode` defaults to `off`. A row IS written, then
 *      marked `suppressed`. `log` writes the whole message to the application
 *      log instead of sending, which is the setting to use first.
 *
 *   3. The mail package.  ColdFusion 2021 and later ship modular, and `mail` is
 *      not installed by default. Nothing in the CMS can see this, and the
 *      failure is not a catchable CFML exception — the request simply dies.
 *      `cfpm install mail`, then restart.
 *
 *   4. The mail server.  `MailService` calls ColdFusion's `mail()` without
 *      server details, so delivery depends on an SMTP server configured in the
 *      ColdFusion Administrator. Nothing in the CMS supplies one, and nothing in
 *      the CMS can see whether one exists.
 *
 * This walks all three in order and says which one stopped it.
 *
 * ## Running it
 *
 *     cp resources/tools/MailCheck.cfm public/__mailcheck.cfm
 *     curl "http://127.0.0.1/__mailcheck.cfm"
 *     curl "http://127.0.0.1/__mailcheck.cfm?to=you@example.com"
 *     rm public/__mailcheck.cfm
 *
 * Without `to` it only reports configuration. With `to` it sends one through
 * `MailService`, which honours every setting above — so its outcome is exactly
 * what a real notification would do, and the recorded status says which of the
 * four steps stopped it.
 */

/* ------------------------------------------------------------------ guard */

if ( !listFindNoCase( "127.0.0.1,::1,0:0:0:0:0:0:0:1", cgi.remote_addr ) ) {
	writeOutput( "Refused: run this from the server itself, over 127.0.0.1." & chr(10) );
	writeOutput( "Saw remote address [" & cgi.remote_addr & "]." & chr(10) );
	abort;
}

out = [];
function say( line = "" ){ arrayAppend( out, arguments.line ); }
/**
 * Print what has been gathered, and push it to the client immediately.
 *
 * `cfflush` matters, not just `writeOutput`: an uncaught error replaces the
 * whole response buffer with ColdFusion's error page, so anything merely
 * written is lost. Flushed bytes are already gone and survive. That is what
 * lets this tool report its findings even when the very next line kills the
 * request — which is exactly what a missing `mail` package does.
 */
function flush(){
	writeOutput( arrayToList( out, chr(10) ) & chr(10) );

	try {
		cfflush();
	} catch ( any e ) {
		// Already flushed, or a context that will not allow it. Harmless.
	}
}

if ( !structKeyExists( application, "wirebox" ) ) {
	writeOutput( "The application has not booted, so nothing can be checked." & chr(10) );
	abort;
}

wb   = application.wirebox;
// Not named `mail`: that shadows CFML's `mail()` tag-in-script,
// and the bare cfmail below then fails with "Entity has incorrect
// type for being called as a function" — which reads exactly like
// a mail server fault and is not one.
mailService = wb.getInstance( "MailService@core" );
to   = trim( url.to ?: "" );

/* ----------------------------------------------------- 1. the module gate */

say( "1. MODULE NOTIFICATIONS" );

gates = { "contact" : "", "forms" : "" };

for ( moduleName in gates ) {
	try {
		moduleSettings = wb.getInstance( "coldbox:moduleSettings:" & moduleName );
		notifyOn = moduleSettings.sendNotifications ?: false;

		say( "   " & moduleName & ".sendNotifications = " & ( notifyOn ? "TRUE" : "false" )
			& ( notifyOn ? "" : "   <- nothing is even queued" ) );
	} catch ( any e ) {
		say( "   " & moduleName & " module is not loaded (" & e.message & ")" );
	}
}

say( "" );

/* -------------------------------------------------------- 2. the mail mode */

mode = mailService.getMode();
core = wb.getInstance( "coldbox:moduleSettings:core" );

say( "2. MAIL MODE" );
say( "   core.mailMode = " & mode );

switch ( mode ) {
	case "off":
		say( "                   <- queued and then suppressed; nothing is sent" );
		break;
	case "log":
		say( "                   <- written to app/logs/app.log instead of sent" );
		break;
	default:
		say( "                   <- delivery is attempted" );
}

say( "   core.mailFrom = " & ( core.mailFrom ?: "unset" ) );

if ( ( core.mailFrom ?: "" ) == "no-reply@localhost" ) {
	say( "                   <- still the default. Most servers reject this," );
	say( "                      and most spam filters distrust it." );
}

say( "" );

/* ------------------------------------------------------------ what exists */

say( "3. WHAT HAS BEEN ATTEMPTED" );

counts = queryExecute( "SELECT status, COUNT(*) AS n FROM mail_messages GROUP BY status" );

if ( !counts.recordCount ) {
	say( "   No rows in `mail_messages` at all." );
	say( "   A row is written BEFORE any send is attempted, so an empty table" );
	say( "   means nothing has ever reached the mail layer — which points at" );
	say( "   step 1, not at the mail server." );
} else {
	for ( row in counts ) {
		say( "   " & row.status & " = " & row.n );
	}

	failures = queryExecute( "
		SELECT id, to_address, subject, error, created_at
		FROM mail_messages WHERE status = 'failed'
		ORDER BY id DESC LIMIT 5
	" );

	if ( failures.recordCount ) {
		say( "" );
		say( "   most recent failures:" );
		for ( row in failures ) {
			say( "     ##" & row.id & " " & dateTimeFormat( row.created_at, "yyyy-mm-dd HH:nn" )
				& " to " & row.to_address );
			say( "        " & ( row.error ?: "" ) );
		}
	}
}

say( "" );

/* --------------------------------------------------------- 4. actually try */

if ( !len( to ) ) {
	say( "4. DELIVERY" );
	say( "   Not tested. Add ?to=you@example.com to send two test messages." );
	flush();
	abort;
}

say( "4. DELIVERY TO " & to );
say( "" );

// Printed NOW, before anything is attempted. On ColdFusion 2021 and later the
// mail tag lives in an installable package, and when it is missing the failure
// is not a catchable CFML exception — the request dies and takes the buffered
// report with it. Flushing first means the findings above survive, and the
// point at which output stops is itself the diagnosis.
flush();
out = [];

// Through the CMS, honouring every setting. This is what a real notification
// does, so its outcome is the one that explains a missing email.
say( "   Through MailService, obeying every setting above:" );

try {
	result = mailService.send(
		to       = to,
		subject  = "myCFCMS mail check " & dateTimeFormat( now(), "HH:nn:ss" ),
		body     = "<p>Sent through MailService.</p>",
		type     = "html"
	);

	say( "      queued as row ##" & result.id & ", status: " & result.status );

	if ( result.status == "suppressed" ) {
		say( "      Suppressed by `mailMode`, not by a mail server problem." );
	}
} catch ( any e ) {
	say( "      REFUSED: " & e.type & " — " & e.message );
}

say( "" );

// Deliberately no raw `cfmail` here.
//
// Where the mail package is missing, calling it takes the whole request down —
// not as a catchable exception, so the report gathered above would be replaced
// by ColdFusion's error page and this tool would tell you nothing. Going
// through MailService is the better test anyway: it is what a real notification
// does, it fails gracefully, and it names the cause.

say( "" );
say( "Delete this file from the webroot now." );

flush();
</cfscript>
