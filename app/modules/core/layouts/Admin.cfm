<cfscript>
	/**
	 * Is this section the one being viewed?
	 *
	 * `exact` exists for the dashboard, whose href `/admin` prefixes every
	 * other admin URL and would otherwise stay highlighted everywhere.
	 */
	function isCurrentSection( required struct section, required string path ){
		if ( arguments.section.exact ?: false ) {
			return arguments.path eq arguments.section.match;
		}

		return arguments.path eq arguments.section.match
			|| left( arguments.path, len( arguments.section.match ) + 1 ) eq arguments.section.match & "/";
	}
</cfscript>
<cfoutput>
<!doctype html>
<html lang="en">
<head>
	<meta charset="utf-8">
	<meta name="viewport" content="width=device-width, initial-scale=1">
	<meta name="robots" content="noindex, nofollow">
	<title>#encodeForHTML( prc.pageTitle ?: "Admin" )# &middot; #encodeForHTML( prc.currentSite.getName() )#</title>
	<cfinclude template="/core/layouts/_styles.cfm">
</head>
<body>

<header class="adm-top">
	<div class="adm-wrap">
		<a class="adm-brand" href="/admin">myCFCMS <span>admin</span></a>

		<cfset local.currentPath = prc.currentPath ?: "/admin">

		<nav class="adm-nav">
			<cfloop array="#prc.adminNav ?: []#" index="local.entry">
				<cfif local.entry.type eq "link">
					<cfset local.navItem = local.entry>
					<cfinclude template="/core/views/admin/_navLink.cfm">
				<cfelse>
					<!---
						`<details>` rather than a hover menu: it opens on click
						or Enter, closes on Escape, and is reachable from the
						keyboard without a line of script. A CSS-only hover
						dropdown is none of those things on a touch screen.
					--->
					<cfset local.groupOpen = false>
					<cfloop array="#local.entry.items#" index="local.child">
						<cfif isCurrentSection( local.child, local.currentPath )>
							<cfset local.groupOpen = true>
						</cfif>
					</cfloop>

					<details class="adm-menu">
						<summary class="#local.groupOpen ? 'is-current' : ''#">#encodeForHTML( local.entry.label )#</summary>
						<div class="adm-menu-panel">
							<cfloop array="#local.entry.items#" index="local.navItem">
								<cfinclude template="/core/views/admin/_navLink.cfm">
							</cfloop>
						</div>
					</details>
				</cfif>
			</cfloop>
			<a href="/" target="_blank" rel="noopener">View site &nearr;</a>
		</nav>

		<span class="adm-site" title="The site you are editing">
			Site <strong>#encodeForHTML( prc.currentSite.getName() )#</strong>
		</span>

		<span class="adm-user">
			#encodeForHTML( prc.currentUser.getName() )#<cfif prc.currentUser.isSuperAdmin()> <span class="adm-tag-super">super</span></cfif>
			&middot;
			<form class="inline" method="post" action="/admin/auth/logout">
				<input type="hidden" name="csrfToken" value="#encodeForHTMLAttribute( prc.csrfToken ?: "" )#">
				<button type="submit" class="linkish">Log out</button>
			</form>
		</span>
	</div>
</header>

<main class="adm-wrap adm-main">
	<cfif len( flash.get( "message", "" ) )>
		<p class="flash #encodeForHTMLAttribute( flash.get( 'messageType', 'success' ) )#">#encodeForHTML( flash.get( "message" ) )#</p>
	</cfif>
	<cfif len( prc.message ?: "" )>
		<p class="flash #encodeForHTMLAttribute( prc.messageType ?: 'success' )#">#encodeForHTML( prc.message )#</p>
	</cfif>

	#renderView()#
</main>

<footer class="adm-foot">
	<div class="adm-wrap">
		myCFCMS &middot; ColdFusion 2025 + MySQL &middot;
		site <code>#encodeForHTML( prc.currentSite.getSlug() )#</code> &middot;
		signed in as <code>#encodeForHTML( prc.currentUser.getEmail() )#</code>
	</div>
</footer>

<!---
	The media picker is unconditional; the editor is not. Settings needs the
	picker for the site logo and has no rich-text field, so gating it on
	`useEditor` would leave that screen with a button that does nothing.
--->
<cfinclude template="/core/layouts/_picker.cfm">

<cfif prc.useEditor ?: false>
	<cfinclude template="/core/layouts/_editor.cfm">
</cfif>
<script>
/*
	Closes an open navigation menu on Escape or a click elsewhere.

	`<details>` gives us open, close and keyboard operation for free; the one
	thing it does not do is close when attention moves away, which leaves a
	panel hanging over the page. Progressive: without this the menus still
	work, they just need a second click to dismiss.
*/
(function () {
	var menus = document.querySelectorAll( ".adm-menu" );

	if ( !menus.length ) {
		return;
	}

	function closeAll( except ) {
		menus.forEach( function ( menu ) {
			if ( menu !== except ) {
				menu.open = false;
			}
		} );
	}

	menus.forEach( function ( menu ) {
		// One at a time: two panels overlapping is never what was wanted.
		menu.addEventListener( "toggle", function () {
			if ( menu.open ) {
				closeAll( menu );
			}
		} );
	} );

	document.addEventListener( "click", function ( event ) {
		if ( !event.target.closest( ".adm-menu" ) ) {
			closeAll();
		}
	} );

	document.addEventListener( "keydown", function ( event ) {
		if ( event.key === "Escape" ) {
			closeAll();
		}
	} );
})();
</script>
</body>
</html>
</cfoutput>
