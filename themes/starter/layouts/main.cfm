<cfoutput>
<!doctype html>
<html lang="#encodeForHTMLAttribute( args.site.getLocale() )#">
<head>
	<meta charset="utf-8">
	<meta name="viewport" content="width=device-width, initial-scale=1">
	<title>#encodeForHTML( args.title )#</title>
	<cfif len( args.metaDescription )>
		<meta name="description" content="#encodeForHTML( args.metaDescription )#">
	</cfif>
	<style>
		body { margin:0; font:16px/1.7 Georgia, "Times New Roman", serif; background:##faf8f4; color:##2b2b2b; }
		.sheet { max-width:38rem; margin:0 auto; padding:3rem 1.25rem; }
		.brand { letter-spacing:.18em; text-transform:uppercase; font-size:.75rem; color:##8a7f6d; }
		nav a { margin-right:1rem; color:##7a5c2e; }
		h1 { font-size:2.1rem; margin:.25rem 0 1rem; }
	</style>
</head>
<body>
	<div class="sheet" data-theme="starter">
		<p class="brand">#encodeForHTML( args.site.getName() )#</p>
		<nav>
			<cfloop array="#args.navigation#" index="item">
				<a href="/#encodeForHTML( item.getPath() )#">#encodeForHTML( item.getTitle() )#</a>
			</cfloop>
		</nav>
		<main>#args.body#</main>
	</div>
</body>
</html>
</cfoutput>
