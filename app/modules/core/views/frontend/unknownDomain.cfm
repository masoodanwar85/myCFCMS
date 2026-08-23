<cfoutput>
<!doctype html>
<html lang="en">
<head>
	<meta charset="utf-8">
	<meta name="viewport" content="width=device-width, initial-scale=1">
	<meta name="robots" content="noindex">
	<title>Site not found</title>
	<style>
		body { margin:0; min-height:100vh; display:grid; place-items:center;
		       font:16px/1.6 -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif;
		       color:##1a1a1a; background:##fafafa; }
		.box { max-width:32rem; padding:2rem; text-align:center; }
		h1 { font-size:1.4rem; margin:0 0 .5rem; }
		p { color:##666; margin:.4rem 0; }
		code { background:##eee; padding:.15rem .4rem; border-radius:3px; }
	</style>
</head>
<body>
	<div class="box">
		<h1>No site is configured for this address</h1>
		<cfif len( prc.requestedHost ?: "" )>
			<p><code>#encodeForHTML( prc.requestedHost )#</code> is not registered as an active domain.</p>
		</cfif>
		<p>If you expected a site here, check that the domain is added and active,
		   and that the site itself is active.</p>
	</div>
</body>
</html>
</cfoutput>
