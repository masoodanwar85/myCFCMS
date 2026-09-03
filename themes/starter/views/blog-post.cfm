<cfoutput>
<article data-view="starter-blog-post">
	<cfif args.post.getShowHeading()>
		<h1>#encodeForHTML( args.post.getTitle() )#</h1>
	</cfif>
	#args.post.getContent()#
</article>
</cfoutput>
