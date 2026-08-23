<cfoutput>
<article data-view="starter-page">
	<h1>#encodeForHTML( args.page.getTitle() )#</h1>
	#args.page.getContent()#
</article>
</cfoutput>
