<cfoutput>
<!doctype html>
<html lang="en">
<head>
	<meta charset="utf-8">
	<meta name="viewport" content="width=device-width, initial-scale=1">
	<meta name="robots" content="noindex, nofollow">
	<title>Sign in &middot; #encodeForHTML( prc.currentSite.getName() )#</title>
	<cfinclude template="/core/layouts/_styles.cfm">
</head>
<body class="adm-login-body">
	<div class="adm-login">
		<cfif len( flash.get( "message", "" ) )>
			<p class="flash #encodeForHTMLAttribute( flash.get( 'messageType', 'success' ) )#">#encodeForHTML( flash.get( "message" ) )#</p>
		</cfif>
		#renderView()#
	</div>
</body>
</html>
</cfoutput>
