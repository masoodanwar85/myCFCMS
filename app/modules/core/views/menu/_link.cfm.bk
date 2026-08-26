<cfoutput>
<!---
	One navigation link. Expects `local.navItem`.

	Its own file so the two levels in _nav.cfm cannot drift apart — the
	`noopener` on an external link is the sort of detail that gets added to one
	copy and forgotten in the other.
--->
<cfset local.navTarget   = structKeyExists( local.navItem, "target" ) ? local.navItem.target : "">
<cfset local.navExternal = structKeyExists( local.navItem, "external" ) && local.navItem.external>
<a href="#xmlFormat( local.navItem.href )#"<cfif len( local.navTarget )> target="#xmlFormat( local.navTarget )#"<cfif local.navExternal><!---
	A page opened with target="_blank" can otherwise reach back through
	window.opener and navigate the page it was opened from.
---> rel="noopener"</cfif></cfif>>#encodeForHTML( local.navItem.label )#</a>
</cfoutput>
