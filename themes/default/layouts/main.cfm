<cfoutput>
<!doctype html>
<html lang="#encodeForHTMLAttribute( args.site.getLocale() )#">
<head>
	<meta charset="utf-8">
	<meta name="viewport" content="width=device-width, initial-scale=1">
	<title>#encodeForHTML( args.title )#</title>
	<cfif len( args.seo.description ?: args.metaDescription )>
		<meta name="description" content="#xmlFormat( args.seo.description ?: args.metaDescription )#">
	</cfif>
	<cfinclude template="/core/views/seo/_head.cfm">
	<style>
		:root { --ink:##1a1a1a; --muted:##666; --rule:##e5e5e5; --link:##0b5fff; }
		* { box-sizing: border-box; }
		body { margin:0; font:16px/1.6 -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif;
		       color:var(--ink); background:##fff; }
		.wrap { max-width: 44rem; margin: 0 auto; padding: 2rem 1.25rem 4rem; }
		header { border-bottom:1px solid var(--rule); margin-bottom:2rem; }
		header .site { font-weight:600; font-size:1.1rem; text-decoration:none; color:var(--ink); }
		nav { margin: .75rem 0 1.25rem; }
		nav ul { list-style:none; margin:0; padding:0; }
		nav > ul { display:flex; flex-wrap:wrap; gap:1rem; }
		nav a { text-decoration:none; color:var(--link); }
		/* One level of children, shown inline under their parent rather than
		   as a hover menu: a dropdown needs script and a keyboard story, and
		   this theme is meant to be the plain one. */
		nav ul ul { display:flex; gap:.75rem; margin-top:.2rem; }
		nav ul ul a { font-size:.85rem; color:var(--muted); }
		h1 { font-size:1.9rem; line-height:1.25; margin:0 0 .5rem; }
		.crumbs { font-size:.85rem; color:var(--muted); margin-bottom:1.5rem; }
		.crumbs a { color:var(--muted); }
		footer { margin-top:3rem; padding-top:1rem; border-top:1px solid var(--rule);
		         font-size:.85rem; color:var(--muted); }
	</style>
</head>
<body>
	<div class="wrap">
		<header>
			<a class="site" href="/">#encodeForHTML( args.site.getName() )#</a>
			<nav>
				<cfset local.navItems = args.navigation>
				<cfinclude template="/core/views/menu/_nav.cfm">
			</nav>
		</header>

		<main>#args.body#</main>

		<footer>
			#encodeForHTML( args.site.getName() )# &mdash; rendered by the <strong>#encodeForHTML( args.theme.getTitle() )#</strong> theme
		</footer>
	</div>
	<cfinclude template="/core/views/seo/_body.cfm">
</body>
</html>
</cfoutput>
