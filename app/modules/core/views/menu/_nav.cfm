<cfoutput>
<!---
	A site's navigation, to whatever depth MenuService allows.

	Recursive, and the recursion is the interesting part. A self-including view
	shares one `local` scope with every level of itself, so the naive version
	loses the outer loop's state the moment an inner level runs. This keeps each
	level's items in `local.navLevels[ depth ]` and restores the depth counter on
	the way back out, so a level only ever reads its own slot.

	The two variables that *are* shared — `local.navItem` and `local.navKids` —
	are only read before the recursive include, never after it, so a nested
	level clobbering them cannot affect the level above.

	Written this way rather than as a function because a `<cffunction>` in an
	included template is defined in the including scope, and would collide the
	second time a page renders a menu.

	A theme is free to ignore this: `args.navigation` is plain structs.
--->
<cfif !structKeyExists( local, "navDepth" )><cfset local.navDepth = 0></cfif>
<cfif !structKeyExists( local, "navLevels" )><cfset local.navLevels = {}></cfif>

<cfset local.navDepth = local.navDepth + 1>
<cfset local.navLevels[ local.navDepth ] = local.navItems>

<cfif arrayLen( local.navLevels[ local.navDepth ] )>
	<ul class="nav-level nav-level-#local.navDepth#">
		<cfloop array="#local.navLevels[ local.navDepth ]#" index="local.navItem">
			<cfset local.navKids = structKeyExists( local.navItem, "children" ) ? local.navItem.children : []>
			<li<cfif arrayLen( local.navKids )> class="has-children"</cfif>>
				<cfinclude template="/core/views/menu/_link.cfm">

				<cfif arrayLen( local.navKids )>
					<cfset local.navItems = local.navKids>
					<cfinclude template="/core/views/menu/_nav.cfm">
				</cfif>
			</li>
		</cfloop>
	</ul>
</cfif>

<cfset local.navDepth = local.navDepth - 1>
</cfoutput>
