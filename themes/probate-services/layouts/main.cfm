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
		Cormorant Garamond for display, DM Sans for everything else — the two
		faces the design was drawn in. `display=swap` so the text is readable
		while they load rather than invisible.

		Loaded from Google, which matches the other themes here. It is worth
		knowing what that costs: it makes the site depend on a third party
		being reachable, and tells them about every visitor. Self-hosting the
		two families under this theme's own `fonts/` directory would remove
		both, and is the better answer the day anyone minds.
	--->
	<link rel="preconnect" href="https://fonts.googleapis.com">
	<link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
	<link rel="stylesheet" href="https://fonts.googleapis.com/css2?family=Cormorant+Garamond:ital,wght@0,500;0,600;1,500&family=DM+Sans:wght@400;500;600&display=swap">

	<!---
		The theme's stylesheet, served straight off disk by the web server.
		`assetUrl()` builds the path; the file lives under
		`public/assets/themes/probate-services/`, not beside this layout,
		because `/themes` is deliberately outside the webroot.
	--->
	<link rel="stylesheet" href="#args.theme.assetUrl( 'css/theme.css' )#">
	<link rel="stylesheet" href="/includes/vendor/splide/splide.min.css">
	<link rel="stylesheet" href="/includes/vendor/splide/hero-slider.css">

	<!---
		This site's own colours and fonts, after the stylesheet so they win.
		Emitted only when the site has set something; otherwise the theme's
		defaults stand and this is an empty string.
	--->
	<cfif len( args.branding.styles )>
		<style>#args.branding.styles#</style>
	</cfif>
</head>
<body>
<!---
	Tag Manager's fallback for a visitor with JavaScript off. Google requires it
	immediately after `<body>`, and it is empty for a GA4 `G-` tag or when no
	tag is configured.
--->
<cfif len( args.analytics.body ?: "" )>#args.analytics.body#</cfif>

<cfscript>
	/*
	 * The practice's own details, lifted into plain variables once.
	 *
	 * Not a `has()` closure: inside a closure `local` is the closure's own
	 * scope, so `local.firm` would be undefined in there and every test would
	 * silently answer "not set". Flat variables cost a few lines and cannot
	 * go wrong that way.
	 *
	 * Every field is optional, so each element below asks before it prints —
	 * a site that has filled nothing in gets a working header rather than a
	 * row of empty labels.
	 */
	local.firm        = args.firm ?: {};
	local.trustLine   = trim( local.firm.trustLine   ?: "" );
	local.phone       = trim( local.firm.phone       ?: "" );
	local.email       = trim( local.firm.email       ?: "" );
	local.address     = trim( local.firm.address     ?: "" );
	local.hours       = trim( local.firm.hours       ?: "" );
	local.legalEntity = trim( local.firm.legalEntity ?: "" );
	local.abn         = trim( local.firm.abn         ?: "" );

	// Printed as written, dialled without the spaces.
	local.telHref = reReplace( local.phone, "[^0-9+]", "", "all" );

	// Escaped first, then the line breaks become markup — the other order
	// would encode the <br> we just inserted. A carriage return is dropped so
	// a value pasted from Windows leaves no stray character mid-line.
	// Each line is escaped on its own and then joined with the break.
	// Escaping the whole string first and replacing afterwards does not work:
	// `encodeForHTML` turns the newline into a numeric entity, so there is no
	// chr(10) left to find and the address renders as one line with the entity
	// visible in it.
	local.addressHtml = listToArray( replace( local.address, chr( 13 ), "", "all" ), chr( 10 ) )
		.map( function( line ){ return encodeForHTML( trim( line ) ); } )
		.toList( "<br>" );
</cfscript>

<a class="visually-hidden" href="##main-content">Skip to content</a>

<!--- ============ TOP BAR ============ --->
<cfif len( local.trustLine ) or len( local.hours ) or len( local.phone )>
	<div class="topbar">
		<div class="topbar__inner">
			<cfif len( local.trustLine )>
				<span class="topbar__trust">#encodeForHTML( local.trustLine )#</span>
			<cfelse>
				<span></span>
			</cfif>

			<div class="topbar__side">
				<cfif len( local.hours )>
					<span class="topbar__item">
						<svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="##FFB58A" stroke-width="2" stroke-linecap="round" aria-hidden="true"><circle cx="12" cy="12" r="9"/><path d="M12 7v5l3 2"/></svg>
						#encodeForHTML( local.hours )#
					</span>
				</cfif>
				<cfif len( local.phone )>
					<a class="topbar__item topbar__phone" href="tel:#encodeForHTMLAttribute( local.telHref )#">
						<svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="##FFB58A" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><path d="M5 4h4l2 5-2.5 1.5a11 11 0 0 0 5 5L15 13l5 2v4a2 2 0 0 1-2 2A16 16 0 0 1 3 6a2 2 0 0 1 2-2"/></svg>
						#encodeForHTML( local.phone )#
					</a>
				</cfif>
				<a class="btn btn--xs" href="/contact">Book a consultation</a>
			</div>
		</div>
	</div>
</cfif>

<!--- ============ HEADER ============ --->
<header class="site-head">
	<div class="site-head__bar">
		<div class="brand-logo">
			<!---
				The logo comes from this site's branding setting, uploaded to
				its own media library. No logo set falls back to the site name
				set in the design's wordmark, so a client has a working header
				before they have uploaded anything.
			--->
			<a class="brand" href="/" aria-label="#encodeForHTML( args.site.getName() )#">
				<cfif len( args.branding.logoUrl )>
					<img src="#encodeForHTMLAttribute( args.branding.logoUrl )#"
					     alt="#encodeForHTML( args.site.getName() )#">
				<cfelse>
					<svg width="40" height="47" viewBox="0 0 48 56" fill="none" stroke="##1A5FA8" stroke-linecap="round" aria-hidden="true">
						<path d="M6 54V24a18 18 0 0 1 36 0v30" stroke-width="2"/>
						<path d="M11 54V24a13 13 0 0 1 26 0v30" stroke-width="1" opacity="0.55"/>
						<path d="M2 54h44" stroke-width="2"/>
						<circle cx="24" cy="24" r="5" stroke-width="2"/>
						<path d="M24 29v17M24 40h5M24 45h4" stroke-width="2"/>
					</svg>
					<span class="brand__text">
						<span class="brand__name">#encodeForHTML( args.site.getName() )#</span>
						<cfif !len( local.trustLine ) and len( local.legalEntity )>
							<span class="brand__tag">#encodeForHTML( local.legalEntity )#</span>
						</cfif>
					</span>
				</cfif>
			</a>

			<!---
				`type="button"` because a bare <button> defaults to submit,
				which would post the surrounding form the day this markup moves
				inside one. The listener is bound at the bottom of the page; no
				`onclick` here, or one tap would toggle the class twice and the
				menu would never open.
			--->
			<button type="button" class="nav-toggle" aria-expanded="false" aria-controls="primary-nav" aria-label="Menu">
				<svg width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" aria-hidden="true"><path d="M3 6h18M3 12h18M3 18h18"/></svg>
			</button>
		</div>

		<nav class="nav" id="primary-nav" aria-label="Primary">
			<cfset local.navItems = args.navigation>
			<cfinclude template="/core/views/menu/_nav.cfm">
		</nav>
	</div>
</header>

<main id="main-content">
	#args.body#
</main>

<!--- ============ FOOTER ============ --->
<footer class="site-foot">
	<div class="site-foot__inner">
		<div class="site-foot__grid">
			<div class="site-foot__brand">
				<a class="brand" href="/" aria-label="#encodeForHTML( args.site.getName() )#">
					<cfif len( args.branding.logoUrl )>
						<img src="#encodeForHTMLAttribute( args.branding.logoUrl )#"
						     alt="#encodeForHTML( args.site.getName() )#">
					<cfelse>
						<svg width="36" height="42" viewBox="0 0 48 56" fill="none" stroke="##FFB58A" stroke-linecap="round" aria-hidden="true">
							<path d="M6 54V24a18 18 0 0 1 36 0v30" stroke-width="2"/>
							<path d="M11 54V24a13 13 0 0 1 26 0v30" stroke-width="1" opacity="0.55"/>
							<path d="M2 54h44" stroke-width="2"/>
							<circle cx="24" cy="24" r="5" stroke-width="2"/>
							<path d="M24 29v17M24 40h5M24 45h4" stroke-width="2"/>
						</svg>
						<span class="brand__name" style="color:##fff">#encodeForHTML( args.site.getName() )#</span>
					</cfif>
				</a>
				<p>Probate and deceased estate lawyers acting in every Australian state and territory.</p>
			</div>

			<div class="site-foot__col">
				<span class="site-foot__head">Services</span>
				<a href="/services/grant-of-probate">Grant of Probate</a>
				<a href="/services/letters-of-administration">Letters of Administration</a>
				<a href="/services/estate-administration">Estate Administration</a>
				<a href="/services/reseal-of-a-grant">Reseal of a Grant</a>
			</div>

			<div class="site-foot__col">
				<span class="site-foot__head">Quick links</span>
				<a href="/about">About us</a>
				<a href="/our-people">Our people</a>
				<a href="/guides">Free guides</a>
				<a href="/faq">Questions</a>
				<a href="/contact">Contact</a>
			</div>

			<div class="site-foot__col">
				<span class="site-foot__head">Contact</span>
				<cfif len( local.address )>
					<span>#local.addressHtml#</span>
				</cfif>
				<cfif len( local.phone )>
					<a href="tel:#encodeForHTMLAttribute( local.telHref )#">#encodeForHTML( local.phone )#</a>
				</cfif>
				<cfif len( local.email )>
					<a href="mailto:#encodeForHTMLAttribute( local.email )#">#encodeForHTML( local.email )#</a>
				</cfif>
				<cfif len( local.hours )>
					<span>#encodeForHTML( local.hours )#</span>
				</cfif>
			</div>
		</div>

		<div class="site-foot__legal">
			<span>
				&copy; #year( now() )# #encodeForHTML( args.site.getName() )#.<cfif len( local.legalEntity )>
					#encodeForHTML( local.legalEntity )#</cfif><cfif len( local.abn )>
					&middot; ABN #encodeForHTML( local.abn )#</cfif>
			</span>
			<div>
				<a href="/privacy">Privacy policy</a>
				<a href="/terms">Terms of use</a>
				<a href="/disclaimer">Legal disclaimer</a>
			</div>
		</div>
	</div>
</footer>

<cfinclude template="/core/views/seo/_body.cfm">

<script>
	document.addEventListener('DOMContentLoaded', function () {
		var toggle = document.querySelector('.nav-toggle');
		var nav    = document.getElementById('primary-nav');

		if (toggle && nav) {
			toggle.addEventListener('click', function () {
				var open = nav.classList.toggle('is-open');
				this.setAttribute('aria-expanded', open);
			});
		}

		// On a narrow screen a parent link reveals its children on the first
		// tap and follows its own href on the second. There is no hover to
		// open it with, and a parent that navigated away immediately would
		// make its children unreachable.
		document.querySelectorAll('##primary-nav .dropdown > a.dropdown-toggle').forEach(function (link) {
			link.addEventListener('click', function (e) {
				if (window.innerWidth > 991) { return; }

				var item = this.parentElement;

				if (!item.classList.contains('open')) {
					e.preventDefault();
					e.stopPropagation();

					item.parentElement.querySelectorAll(':scope > .dropdown.open')
						.forEach(function (sibling) { sibling.classList.remove('open'); });

					item.classList.add('open');
				}
			});
		});

		// Mark the page you are actually on. Only an exact match: lighting up
		// every ancestor marked "Services" while you were on a child of it.
		var strip = function (p) { return p.length > 1 ? p.replace(/\/+$/, '') : p; };
		var here  = strip(window.location.pathname);

		document.querySelectorAll('##primary-nav a').forEach(function (link) {
			var href = link.getAttribute('href');

			if (!href || href === '##') { return; }
			if (strip(href) !== here) { return; }

			link.classList.add('active');

			var item = link.closest('li');
			if (item) { item.classList.add('active'); }
		});
	});
</script>

<script src="/includes/vendor/splide/splide.min.js"></script>
<script src="/includes/vendor/splide/hero-slider.js"></script>
</body>
</html>
</cfoutput>
