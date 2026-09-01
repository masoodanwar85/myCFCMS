<cfsetting showdebugoutput="false" requesttimeout="900">
<cfcontent type="text/plain">
<cfscript>
/**
 * Find the CFCs that do not compile on THIS engine.
 *
 * ## Why this exists
 *
 * WireBox registers models by scanning a directory and reading each component's
 * metadata. A component that fails to compile is skipped — silently. The only
 * symptom is an `Injector.InstanceNotFoundException` for that component,
 * reported at the point some *other* object asked for it, naming a file that is
 * perfectly fine. The stack trace points at the consumer; the fault is in the
 * dependency, and nothing on the page says which.
 *
 * This walks every `.cfc` under `/app` and asks ColdFusion to compile it,
 * reporting the ones that fail with the file and the line. That turns "instance
 * not found" into "line 218 of this file", which is the actual question.
 *
 * It matters most across engine versions. This project is developed on
 * ColdFusion 2025 and deployed on 2023, and 2025 accepts syntax 2023 rejects —
 * member functions called on array and struct *literals* being the one that has
 * bitten this codebase repeatedly. Those files compile locally, pass every test
 * locally, and vanish from the injector in production.
 *
 * ## Running it
 *
 *     cp resources/tools/CompileCheck.cfm public/__compilecheck.cfm
 *     curl "http://127.0.0.1/__compilecheck.cfm"
 *     rm public/__compilecheck.cfm
 *
 * Add `?instance=AuthenticationService@core` to also ask WireBox whether a
 * particular binding resolves, which distinguishes "this file does not compile"
 * from "this file was never uploaded".
 *
 * Compiling a component runs its pseudo-constructor — property declarations and
 * any code in the component body outside a function. That is what ColdFusion
 * itself does when WireBox scans, so the exposure is the same as a reinit.
 */

/* ------------------------------------------------------------------ guard */

if ( !listFindNoCase( "127.0.0.1,::1,0:0:0:0:0:0:0:1", cgi.remote_addr ) ) {
	writeOutput( "Refused: run this from the server itself, over 127.0.0.1." & chr(10) );
	writeOutput( "Saw remote address [" & cgi.remote_addr & "]." & chr(10) );
	abort;
}

out = [];
function say( line = "" ){ arrayAppend( out, arguments.line ); }
function flush(){ writeOutput( arrayToList( out, chr(10) ) & chr(10) ); }

say( "Engine:  " & server.coldfusion.productName & " " & server.coldfusion.productVersion );
say( "Root:    " & expandPath( "/app" ) );
say( "" );

/* ------------------------------------------------ optional instance probe */

wanted = trim( url.instance ?: "" );

if ( len( wanted ) ) {
	say( "WireBox probe for [" & wanted & "]" );

	if ( !structKeyExists( application, "wirebox" ) ) {
		say( "  application.wirebox does not exist — the app has not booted." );
	} else {
		try {
			application.wirebox.getInstance( wanted );
			say( "  RESOLVES." );
		} catch ( any e ) {
			say( "  FAILS: " & e.type );
			say( "  " & e.message );
			if ( len( e.detail ?: "" ) ) { say( "  " & e.detail ); }
		}
	}

	say( "" );
}

/* ------------------------------------------------------- compile everything */

root = expandPath( "/app" );

if ( !directoryExists( root ) ) {
	say( "No /app mapping on this server. Cannot scan." );
	flush();
	abort;
}

files    = directoryList( root, true, "path", "*.cfc" );
failures = [];
checked  = 0;

// Not named `file`: ColdFusion has a built-in `file` scope, and assigning to it
// yields "Complex object types cannot be converted to simple values" the moment
// you try to read it back as a string.
for ( cfcPath in files ) {
	// Path -> dotted component name, relative to the /app mapping.
	relative = replace( replace( cfcPath, root, "" ), "\", "/", "all" );
	relative = reReplace( relative, "^/", "" );
	relative = reReplace( relative, "\.cfc$", "" );

	dotted = "app." & replace( relative, "/", ".", "all" );

	checked++;

	try {
		getComponentMetaData( dotted );
	} catch ( any e ) {
		// The line number lives in the tag context, not on the exception.
		line = "";
		if ( isArray( e.tagContext ?: "" ) && arrayLen( e.tagContext ) ) {
			line = e.tagContext[ 1 ].line ?: "";
		}

		arrayAppend( failures, {
			"file"    : cfcPath,
			"line"    : line,
			"type"    : e.type ?: "",
			"message" : e.message ?: "",
			"detail"  : e.detail ?: ""
		} );
	}
}

/* -------------------------------------------------------------- reporting */

say( "Checked " & checked & " components." );
say( "" );

if ( !arrayLen( failures ) ) {
	say( "All of them compile on this engine." );
	say( "" );
	say( "So a missing WireBox instance is not a compile failure. Check that the" );
	say( "file is actually on this server, and that the app has been reinitialised" );
	say( "since it was uploaded." );
	flush();
	abort;
}

say( arrayLen( failures ) & " DO NOT COMPILE:" );
say( "" );

for ( failure in failures ) {
	say( failure.file & ( len( failure.line ) ? "  (line " & failure.line & ")" : "" ) );
	say( "    " & failure.type );
	say( "    " & failure.message );
	if ( len( failure.detail ) ) { say( "    " & failure.detail ); }
	say( "" );
}

say( "Each of these is invisible to WireBox, so anything injecting one of them" );
say( "fails with Injector.InstanceNotFoundException naming the consumer." );

flush();
</cfscript>
