<cfoutput>
<article data-view="starter-page">
	<cfif args.page.getShowHeading()>
		<h1>#encodeForHTML( args.page.getTitle() )#</h1>
	</cfif>
	#args.page.getContent()#
</article>
</cfoutput>
