<cfoutput>
<article data-view="starter-blog-post">
	<h1>#encodeForHTML( args.post.getTitle() )#</h1>
	#args.post.getContent()#
</article>
</cfoutput>
