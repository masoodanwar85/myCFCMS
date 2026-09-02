<cfoutput>
<!---
	One navigation link. Expects `local.navItem`.

	Its own file so the two levels in _nav.cfm cannot drift apart — the
	`noopener` on an external link is the sort of detail that gets added to one
	copy and forgotten in the other.
--->
<cfset local.navTarget   = structKeyExists( local.navItem, "target" ) ? local.navItem.target : "">
<cfset local.navExternal = structKeyExists( local.navItem, "external" ) && local.navItem.external>

<!---
	`dropdown-toggle` marks a link that OPENS something; `dropdown-item` marks
	one that goes somewhere. That is a question about the item, not about how
	deep it sits.

	This used to key off `navDepth`, which got both ends wrong on a menu deeper
	than two levels: every top-level item was a toggle even with no children,
	and a third-level parent *with* children was an item — so on mobile it
	navigated away instead of revealing its children, and the caret rule for
	nested parents (`ul.dropdown-menu > li.dropdown > a.dropdown-toggle::after`)
	never matched anything.

	Derived from `navItem` rather than read from the caller's `local.navKids`,
	so this file stays self-contained: every level of the recursion shares one
	`local` scope, and depending on a variable the caller happens to have set is
	how that recursion goes wrong.
--->
<cfset local.navLinkKids = structKeyExists( local.navItem, "children" ) ? local.navItem.children : []>

<a href="#xmlFormat( local.navItem.href )#" class="nav-link <cfif arrayLen( local.navLinkKids )>dropdown-toggle<cfelse>dropdown-item</cfif>" <cfif len( local.navTarget )> target="#xmlFormat( local.navTarget )#"<cfif local.navExternal><!---
	A page opened with target="_blank" can otherwise reach back through
	window.opener and navigate the page it was opened from.
---> rel="noopener"</cfif></cfif>>#encodeForHTML( local.navItem.label )#</a>
</cfoutput>
