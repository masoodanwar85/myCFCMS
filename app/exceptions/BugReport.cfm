<cfscript>
/**
 * Which bug report a visitor sees.
 *
 * Set as `customErrorTemplate` for *every* environment, which is the point:
 * the amount of detail shown is decided per viewer, not per deployment. An
 * allowlisted address gets the full report; everyone else gets the public page
 * that names the exception type and nothing more.
 *
 * ## Why not just switch on the development environment
 *
 * Two reasons, both discovered the hard way.
 *
 * First, ColdBox reads `ENVIRONMENT` with `getSystemSetting()`, which checks
 * JVM system properties and OS environment variables — never the `.env` file.
 * CommandBox is what loads `.env` into the JVM at `server start`. Deployed
 * under Apache and ColdFusion there is no CommandBox, so `ENVIRONMENT` is
 * unset, the environment resolves to `production`, and `development()` never
 * runs no matter what `.env` says.
 *
 * Second, `development()` selects `Whoops.cfm`, which loads its CSS and JS from
 * `/coldbox/system/exceptions/`. That path is web-reachable locally only
 * because `server.json` declares an alias for it. `lib/coldbox` sits outside
 * the webroot, so on a real web server those requests 404 and Whoops renders as
 * an unstyled, non-functional shell — detail technically present, practically
 * unreadable.
 *
 * `BugReport.cfm` has no external assets at all. It is the right template for
 * anywhere that is not CommandBox.
 *
 * ## Scope
 *
 * `cgi.remote_addr` is the real client address behind Apache and mod_jk. Behind
 * a CDN it would be the edge node instead, and this gate would then be wrong —
 * check `X-Forwarded-For` if that ever becomes the topology.
 */

// -------------------------------------------------------------------------
// Addresses that may see full exception detail. Loopback covers a request
// made from the server itself; add your own address to debug remotely, and
// take it out again when you are done.
// -------------------------------------------------------------------------
cbxDebugIPs = "127.0.0.1,::1,0:0:0:0:0:0:0:1";

cbxRemoteIP   = trim( cgi.remote_addr ?: "" );
cbxShowDetail = len( cbxRemoteIP ) && listFindNoCase( cbxDebugIPs, cbxRemoteIP ) > 0;
</cfscript>
<cfif cbxShowDetail>
	<cfoutput>
	<!---
		The detected environment, stated outright. `.env` saying `development`
		and ColdBox having *detected* development are different claims, and the
		gap between them is not otherwise visible from a browser.
	--->
	<div style="font:13px/1.5 ui-monospace,SFMono-Regular,Menlo,monospace;background:##1f2937;color:##e5e7eb;padding:10px 14px;">
		environment: <strong>#encodeForHTML( controller.getSetting( "environment" ) )#</strong>
		&nbsp;|&nbsp; shown because #encodeForHTML( cbxRemoteIP )# is allowlisted in /app/exceptions/BugReport.cfm
	</div>
	</cfoutput>
	<cfinclude template="/coldbox/system/exceptions/BugReport.cfm">
<cfelse>
	<!---
		Deliberately NOT `/coldbox/system/exceptions/BugReport-Public.cfm`.

		Despite the name, that template prints `#oException.getMessage()#`
		whenever the exception struct is a struct — which is always — so the
		"public" page publishes the full error message. Worse, it prints it
		unencoded, and exception messages routinely quote user input back:
		"The domain [...] is already assigned to a site." A crafted hostname
		would land as markup on a 500 page.

		This shows the type and nothing else. The type is a class name, safe to
		display and enough for someone to quote when they report a problem. The
		message, detail and stack trace are in `app/logs/app.log`, written by
		`Main.onException`.
	--->
	<cfoutput>
	<!doctype html>
	<html lang="en">
	<head>
		<meta charset="utf-8">
		<meta name="viewport" content="width=device-width, initial-scale=1">
		<meta name="robots" content="noindex, nofollow">
		<title>Something went wrong</title>
		<style>
			body { margin:0; min-height:100vh; display:flex; align-items:center; justify-content:center;
			       font:16px/1.6 -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Helvetica, Arial, sans-serif;
			       background:##f7f5f0; color:##1f2937; }
			.box { max-width:34rem; padding:2.5rem; text-align:center; }
			h1   { margin:0 0 .75rem; font-size:1.5rem; font-weight:600; color:##0f2a4a; }
			p    { margin:0 0 1.25rem; color:##4b5563; }
			code { font:13px/1.5 ui-monospace, SFMono-Regular, Menlo, monospace;
			       background:##ece9e1; padding:.2rem .45rem; border-radius:.25rem; color:##374151; }
		</style>
	</head>
	<body>
		<div class="box">
			<h1>Something went wrong</h1>
			<p>This page could not be displayed. The problem has been logged and will be looked at.</p>
			<cfif len( oException.getType() )>
				<p><code>#encodeForHTML( oException.getType() )#</code></p>
			</cfif>
		</div>
	</body>
	</html>
	</cfoutput>
</cfif>
