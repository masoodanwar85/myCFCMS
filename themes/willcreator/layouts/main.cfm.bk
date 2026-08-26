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

	<!---
		Fonts and colours taken from the live site's own stylesheet rather than
		guessed: Inter for headings, Source Serif 4 for body, navy #0f2a4a on a
		warm #f7f5f0 ground with a gold accent. `display=swap` so text is
		readable while the webfont loads instead of invisible.
	--->
	<link rel="preconnect" href="https://fonts.googleapis.com">
	<link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
	<link rel="stylesheet"
	      href="https://fonts.googleapis.com/css2?family=Inter:wght@500;600;700&family=Source+Serif+4:ital,wght@0,400;0,600;1,400&display=swap">

	<style>
		:root{
			--ink:##1f2a37; --navy:##0f2a4a; --deep:##003366; --gold:##C19B43;
			--ground:##f7f5f0; --card:##ffffff; --rule:##e6e1d6; --muted:##5b6675;
			--sans:'Inter',-apple-system,BlinkMacSystemFont,'Segoe UI',sans-serif;
			--serif:'Source Serif 4',Georgia,'Times New Roman',serif;
		}
		*,*::before,*::after{ box-sizing:border-box; }
		html{ background:var(--ground); }
		body{
			margin:0; background:var(--ground); color:var(--ink);
			font-family:var(--serif); font-size:18px; line-height:1.75;
			-webkit-font-smoothing:antialiased; -moz-osx-font-smoothing:grayscale;
		}
		a{ color:var(--deep); }
		.wrap{ max-width:1140px; margin:0 auto; padding:0 1.25rem; }

		/* ---- masthead ------------------------------------------------- */
		.masthead{ background:var(--navy); color:##fff; }
		.masthead .wrap{ display:flex; align-items:center; gap:1.5rem;
		                 min-height:74px; flex-wrap:wrap; }
		.brand{ font-family:var(--sans); font-weight:700; font-size:1.3rem;
		        color:##fff; text-decoration:none; letter-spacing:-.01em; }
		.brand span{ color:var(--gold); }
		.tagline{ font-size:.85rem; color:rgba(255,255,255,.7); font-family:var(--sans); }

		/* ---- navigation ----------------------------------------------- */
		/*
		   Four levels deep. The first row sits in the bar; every level below it
		   is a panel that opens on hover *or* keyboard focus — `focus-within` is
		   what makes the deeper levels reachable by tabbing, which a hover-only
		   menu never is.
		*/
		.sitenav{ background:var(--deep); font-family:var(--sans); }
		.sitenav ul{ list-style:none; margin:0; padding:0; }
		.sitenav a{ display:block; color:##fff; text-decoration:none;
		            padding:.7rem .9rem; font-size:.92rem; }
		/* Descendant, not child: the list is wrapped in `.wrap` for the page
		   gutter, so `.sitenav > .nav-level-1` matches nothing. `nav-level-1`
		   only ever appears once, so there is no ambiguity to guard against. */
		.sitenav .nav-level-1{ display:flex; flex-wrap:wrap; }
		.sitenav .nav-level-1 > li{ position:relative; }
		.sitenav .nav-level-1 > li > a:hover,
		.sitenav .nav-level-1 > li:focus-within > a{ background:rgba(255,255,255,.12); }
		/* Literal characters rather than CSS escapes: the file is UTF-8, and a
		   `\203a` escape is one backslash away from rendering as its own
		   source text — which is exactly what it did. */
		.sitenav li.has-children > a::after{ content:" ›"; opacity:.65; }
		.sitenav .nav-level-1 > li.has-children > a::after{ content:" ▾"; }

		.sitenav li ul{
			position:absolute; top:100%; left:0; z-index:60; min-width:16rem;
			background:##fff; border:1px solid var(--rule); border-radius:6px;
			box-shadow:0 14px 34px rgba(0,0,0,.16); padding:.3rem;
			opacity:0; visibility:hidden; transform:translateY(-4px);
			transition:opacity .12s ease, transform .12s ease;
		}
		/* Levels three and four fly out sideways rather than stacking down. */
		.sitenav li li ul{ top:-.3rem; left:100%; }
		.sitenav li:hover > ul,
		.sitenav li:focus-within > ul{ opacity:1; visibility:visible; transform:none; }
		.sitenav li li{ position:relative; }
		.sitenav li ul a{ color:var(--ink); padding:.45rem .6rem; border-radius:4px;
		                  font-size:.88rem; }
		.sitenav li ul a:hover{ background:var(--ground); color:var(--deep); }

		/* Below the fold of a phone a flyout menu is unusable, so the whole
		   tree simply stacks and stays open. */
		@media (max-width:900px){
			.sitenav .nav-level-1{ display:block; }
			.sitenav li ul{ position:static; opacity:1; visibility:visible;
			                transform:none; box-shadow:none; border:0;
			                background:transparent; padding:0 0 0 1rem; }
			.sitenav li ul a{ color:rgba(255,255,255,.85); }
			.sitenav li ul a:hover{ background:rgba(255,255,255,.12); color:##fff; }
			.sitenav li.has-children > a::after{ content:""; }
		}

		/* ---- content --------------------------------------------------- */
		main{ display:block; padding:2.5rem 0 5rem; }
		.section{
			max-width:820px; margin:0 auto; background:var(--card);
			padding:3rem 3.5rem; border-radius:8px;
			box-shadow:0 4px 24px rgba(0,0,0,.06);
		}
		@media (max-width:700px){ .section{ padding:1.75rem 1.25rem; } }

		.section h1,.section h2,.section h3,.section h4{
			font-family:var(--sans); color:var(--navy); line-height:1.25;
			letter-spacing:-.01em; font-weight:700; margin:1.8em 0 .6em;
		}
		.section h1{ font-size:2.1rem; margin-top:0; }
		.section h2{ font-size:1.4rem; }
		.section h3{ font-size:1.15rem; }
		.section h1 + p{ font-size:1.05rem; color:var(--muted); }
		.section ul,.section ol{ padding-left:1.3rem; }
		.section li{ margin:.35rem 0; }
		.section img{ max-width:100%; height:auto; border-radius:6px; }
		.section hr{ border:0; border-top:1px solid var(--rule); margin:2.5rem 0; }
		blockquote{ margin:1.5rem 0; padding:.4rem 0 .4rem 1.2rem;
		            border-left:3px solid var(--gold); color:var(--muted); font-style:italic; }

		.crumbs{ max-width:820px; margin:0 auto 1rem; font-family:var(--sans);
		         font-size:.83rem; color:var(--muted); }
		.crumbs a{ color:var(--muted); text-decoration:none; }
		.crumbs a:hover{ text-decoration:underline; }

		/* ---- forms ----------------------------------------------------- */
		label{ display:block; font-family:var(--sans); font-weight:600;
		       font-size:.85rem; margin:1.1rem 0 .3rem; color:var(--navy); }
		input[type=text],input[type=email],textarea{
			width:100%; padding:.6rem .7rem; font:inherit; font-size:1rem;
			border:1px solid var(--rule); border-radius:6px; background:##fff;
		}
		textarea{ min-height:9rem; resize:vertical; }
		button,.btn{
			display:inline-block; font-family:var(--sans); font-weight:600;
			font-size:.95rem; padding:.65rem 1.4rem; border-radius:6px;
			border:1px solid var(--gold); background:var(--gold); color:##fff;
			cursor:pointer; text-decoration:none;
		}
		button:hover,.btn:hover{ filter:brightness(.94); }
		.flash{ padding:.8rem 1rem; border-radius:6px; background:##f0f6ec;
		        border:1px solid ##cfe3c4; margin:0 0 1.25rem; }
		.flash.error{ background:##fdecea; border-color:##f5b7b1; color:##922b21; }

		/* ---- footer ---------------------------------------------------- */
		.sitefoot{ background:var(--navy); color:rgba(255,255,255,.75);
		           font-family:var(--sans); font-size:.85rem; padding:2rem 0; }
		.sitefoot a{ color:var(--gold); }
		.sitefoot p{ margin:.35rem 0; }
	</style>
</head>
<body>
	<header class="masthead">
		<div class="wrap">
			<a class="brand" href="/">Will<span>Creator</span></a>
			<span class="tagline">Put your affairs in order, prepare for the future.</span>
		</div>
	</header>

	<nav class="sitenav" aria-label="Main">
		<div class="wrap">
			<cfset local.navItems = args.navigation>
			<cfinclude template="/core/views/menu/_nav.cfm">
		</div>
	</nav>

	<main>
		#args.body#
	</main>

	<footer class="sitefoot">
		<div class="wrap">
			<p><strong>#encodeForHTML( args.site.getName() )#</strong> &mdash; wills, estates and succession law for New South Wales families.</p>
			<p>Liability limited by a scheme approved under Professional Standards Legislation.</p>
			<p>&copy; #dateFormat( now(), "yyyy" )# #encodeForHTML( args.site.getName() )#. <a href="/contact">Contact us</a></p>
		</div>
	</footer>

	<cfinclude template="/core/views/seo/_body.cfm">
</body>
</html>
</cfoutput>
