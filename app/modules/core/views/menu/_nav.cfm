<cfoutput>
<!---
	A site's navigation, up to the two levels MenuService allows.

	Shipped by Core and included by a theme so the fiddly parts — nesting,
	`target`, and the `rel` an external link needs — are written once and
	correctly rather than copied into every theme and left to drift.

	Written flat rather than recursively on purpose. A self-including view
	shares one `local` scope with every level of itself, so the loop variable
	of the outer level has to be saved and restored around the inner include —
	which works until someone raises the depth limit and the restore starts
	reading a value the inner level already overwrote. MenuService caps a menu
	at two levels; this renders exactly two, and no scope has to be juggled.

	A theme is free to ignore this: `args.navigation` is plain structs.
--->
<cfif arrayLen( local.navItems )>
	<ul class="nav-level">
		<cfloop array="#local.navItems#" index="local.navItem">
			<cfset local.navKids = structKeyExists( local.navItem, "children" ) ? local.navItem.children : []>
			<li<cfif arrayLen( local.navKids )> class="has-children"</cfif>>
				<cfinclude template="/core/views/menu/_link.cfm">

				<cfif arrayLen( local.navKids )>
					<ul class="nav-level nav-level--child">
						<cfloop array="#local.navKids#" index="local.navItem">
							<li><cfinclude template="/core/views/menu/_link.cfm"></li>
						</cfloop>
					</ul>
				</cfif>
			</li>
		</cfloop>
	</ul>
</cfif>
</cfoutput>
