<cfoutput>
<!doctype html>
<html lang="en">
<head>
	<meta charset="utf-8">
	<meta name="viewport" content="width=device-width, initial-scale=1">
	<title>Page not found</title>
	<style>
		body { margin:0; min-height:100vh; display:grid; place-items:center;
		       font:16px/1.6 -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif;
		       color:##1a1a1a; background:##fafafa; }
		.box { max-width:32rem; padding:2rem; text-align:center; }
		p { color:##666; }
	</style>
</head>
<body>
	<div class="box">
		<h1>Page not found</h1>
		<p>There is nothing at <code>/#encodeForHTML( prc.requestedPath ?: "" )#</code>.</p>
	</div>
</body>
</html>
</cfoutput>
