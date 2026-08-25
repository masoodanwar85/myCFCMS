<cfoutput>
<!---
	Breadcrumbs sit outside the white card, as a quiet line above it. On a site
	four levels deep they are not decoration: `/legal-services/wills/wills-blue-mountains/wills-katoomba`
	is impossible to place without them.
--->
<cfif args.breadcrumb.len() gt 1>
	<p class="crumbs">
		<cfloop array="#args.breadcrumb#" index="crumb">
			<cfif crumb.getId() neq args.page.getId()>
				<a href="/#xmlFormat( crumb.getPath() )#">#encodeForHTML( crumb.getTitle() )#</a>
				<span aria-hidden="true">&rsaquo;</span>
			<cfelse>
				<span aria-current="page">#encodeForHTML( crumb.getTitle() )#</span>
			</cfif>
		</cfloop>
	</p>
</cfif>

<article class="section">
	<h1>#encodeForHTML( args.page.getTitle() )#</h1>
	#args.page.getContent()#
</article>
</cfoutput>
