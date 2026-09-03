<cfoutput>
<cfif args.breadcrumb.len() gt 1>
	<p class="crumbs">
		<cfloop array="#args.breadcrumb#" index="crumb">
			<cfif crumb.getId() neq args.page.getId()>
				<a href="/#xmlFormat( crumb.getPath() )#">#encodeForHTML( crumb.getTitle() )#</a> /
			<cfelse>
				#encodeForHTML( crumb.getTitle() )#
			</cfif>
		</cfloop>
	</p>
</cfif>

<article>
	<cfif args.page.getShowHeading()>
		<h1>#encodeForHTML( args.page.getTitle() )#</h1>
	</cfif>
	#args.page.getContent()#
</article>
</cfoutput>
