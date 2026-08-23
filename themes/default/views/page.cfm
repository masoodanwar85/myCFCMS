<cfoutput>
<cfif args.breadcrumb.len() gt 1>
	<p class="crumbs">
		<cfloop array="#args.breadcrumb#" index="crumb">
			<cfif crumb.getId() neq args.page.getId()>
				<a href="/#encodeForHTML( crumb.getPath() )#">#encodeForHTML( crumb.getTitle() )#</a> /
			<cfelse>
				#encodeForHTML( crumb.getTitle() )#
			</cfif>
		</cfloop>
	</p>
</cfif>

<article>
	<h1>#encodeForHTML( args.page.getTitle() )#</h1>
	#args.page.getContent()#
</article>
</cfoutput>
