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
	<link rel="stylesheet" href="https://fonts.googleapis.com/css2?family=Inter:wght@500;600;700&family=Source+Serif+4:ital,wght@0,400;0,600;1,400&display=swap">

	<script src="https://code.jquery.com/jquery-3.7.1.min.js"></script>

	<!---
		The theme's stylesheet, served straight off disk by the web server.

		It used to be ~960 lines of inline <style> re-sent with every page view.
		As a file it is fetched once and cached, and editing it no longer means
		editing the layout.

		`assetUrl()` builds the path; the file itself lives under
		`public/assets/themes/willcreator/`, not beside this layout, because
		`/themes` is deliberately outside the webroot — a layout is a .cfm, and
		exposing this directory would make it directly requestable.
	--->
	<link rel="stylesheet" href="#args.theme.assetUrl( 'css/theme.css' )#">

	<!---
		This site's own colours and fonts, after the stylesheet so they win.

		Emitted only when the site has actually set something; otherwise the
		theme's own defaults stand and this is an empty string. The values are
		validated in SiteBrandingService against a hex/font-name pattern, which
		is what makes them safe to interpolate into a style block.
	--->
	<cfif len( args.branding.styles )>
		<style>#args.branding.styles#</style>
	</cfif>
	<script>
		document.addEventListener('DOMContentLoaded', function() {
		  var toggleBtn = document.querySelector('.nav-toggle');
		  var primaryNav = document.getElementById('primary-nav');
		
		  // 1. Mobile Menu Toggle
		  if (toggleBtn && primaryNav) {
			toggleBtn.addEventListener('click', function(e) {
			  e.preventDefault();
			  var isOpen = primaryNav.classList.toggle('is-open');
			  this.setAttribute('aria-expanded', isOpen);
			});
		  }
		
		  // 2. Mobile Submenu Toggle Handler
		  var dropdownLinks = document.querySelectorAll('##primary-nav .dropdown > a.dropdown-toggle');
		
		  dropdownLinks.forEach(function(link) {
			link.addEventListener('click', function(e) {
			  // Execute only on mobile screen widths
			  if (window.innerWidth <= 991) {
				var parentLi = this.parentElement;
		
				// If submenu is not open yet, stop link navigation & toggle open
				if (!parentLi.classList.contains('open')) {
				  e.preventDefault();
				  e.stopPropagation();
		
				  // Close sibling submenus at the exact same level
				  var siblings = parentLi.parentElement.querySelectorAll(':scope > .dropdown.open');
				  siblings.forEach(function(sibling) {
					sibling.classList.remove('open');
				  });
		
				  // Open target dropdown
				  parentLi.classList.add('open');
				}
			  }
			});
		  });
		});
		</script>
</head>
<body>
	<header class="site-head" style="box-shadow: none;">
		<div class="wrap site-head__bar" style="justify-content: flex-start;">
			<div class="brand-logo">
				<!---
					The logo comes from this site's branding setting, uploaded to
					its own media library. It used to be hotlinked from
					willcreator.com.au — which would have broken at the exact
					moment that domain was pointed at this server.

					No logo set falls back to the site name as text, so a second
					client on this theme has a working header before they have
					uploaded anything.
				--->
				<a class="brand" href="/" aria-label="#encodeForHTML( args.site.getName() )#">
					<cfif len( args.branding.logoUrl )>
						<img src="#encodeForHTMLAttribute( args.branding.logoUrl )#"
						     alt="#encodeForHTML( args.site.getName() )#">
					<cfelse>
						<span class="brand__name">#encodeForHTML( args.site.getName() )#</span>
					</cfif>
				</a>
                <button class="nav-toggle" aria-expanded="false" aria-controls="primary-nav" aria-label="Menu" onclick="var n=document.getElementById('primary-nav');var o=n.classList.toggle('is-open');this.setAttribute('aria-expanded',o)">
                  <svg width="22" height="22" viewBox="0 0 24 24" fill="none" stroke="##1C2B27" stroke-width="2"><path d="M3 6h18M3 12h18M3 18h18"/></svg>
                </button>
			</div>
			<nav class="nav" id="primary-nav" aria-label="Primary">
				<cfset local.navItems = args.navigation>
				<cfinclude template="/core/views/menu/_nav.cfm">
			</nav>
			<script>
				document.addEventListener('DOMContentLoaded', () => {
					const currentPath = window.location.pathname;
					const navLinks = document.querySelectorAll('nav a, .menu a');

					navLinks.forEach(link => {
						const linkPath = link.getAttribute('href');

						if (!linkPath || linkPath === '##') return;

						// Handle home path matching explicitly vs other paths
						const isMatch = linkPath === '/' 
						? currentPath === '/' 
						: currentPath.includes(linkPath);

						if (isMatch) {
						link.classList.add('active');

						const parentLi = link.closest('li');
						if (parentLi) {
							parentLi.classList.add('active');
						}
						}
					});
				});
			</script>
		</div>
	</header>

	<main>
		#args.body#
	</main>

	<footer class="site-foot">
		<div class="wrap">
			<div class="site-foot__grid">
				<div class="site-foot__brand">
					<a class="brand" href="/" style="color:##fff">
						<cfif len( args.branding.logoUrl )>
							<img src="#encodeForHTMLAttribute( args.branding.logoUrl )#"
							     alt="#encodeForHTML( args.site.getName() )#">
						<cfelse>
							<span class="brand__name">#encodeForHTML( args.site.getName() )#</span>
						</cfif>
					</a>
					<p>Wills, estates and succession law for New South Wales families. Liability limited by a scheme approved under Professional Standards Legislation.</p>
				</div>
	
				<div>
					<h5>Documents</h5>
					<a href="/create-documents/">Last Will &amp; Testament</a>
					<a href="/create-documents/">Enduring Power of Attorney</a>
					<a href="/create-documents/">Enduring Guardian</a>
				</div>
	
				<div>
					<h5>Firm</h5>
					<a href="/about-us/">About Us</a>
					
					<a href="/solicitors/">Our solicitors</a>
					<a href="/fees/">Fees</a>
					<a href="/contact/">Contact</a>
				</div>
	
				<div>
					<h5>Support</h5>
					<a href="/sign-in/">Sign in</a>
					<a href="/faq/">FAQ</a>
					<a href="/contact/">Book an appointment</a>
				</div>
			</div>
	
			<div class="site-foot__legal">
				<p>&copy; 1994&ndash;#year(now())#  Pty Ltd. All rights reserved.</p>
				<p>
					<a href="/privacy/">Privacy</a> &nbsp;&middot;&nbsp;
					<a href="/terms/">Terms of engagement</a> &nbsp;&middot;&nbsp;
					<a href="/disclaimer/">Disclaimer</a>
				</p>
			</div>
		</div>
	</footer>

	<cfinclude template="/core/views/seo/_body.cfm">
</body>
</html>
</cfoutput>
