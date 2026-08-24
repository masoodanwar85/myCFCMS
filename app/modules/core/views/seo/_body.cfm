<cfoutput>
<!---
	Author-supplied markup for just before `</body>`.

	Its own file rather than a second branch inside `_head.cfm`, because a
	theme includes them in two different places and one of them is easy to
	forget. Emitted raw by design — see PageService.applyRawMarkup for the
	`content.unfiltered` gate that decides who may write it.
--->
<cfset local.seo = args.seo ?: {}>
<cfif len( local.seo.bodyMarkup ?: "" )>
	#local.seo.bodyMarkup#
</cfif>
</cfoutput>
