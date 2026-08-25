<cfoutput>
<p class="crumbs">
	<a href="/#xmlFormat( args.basePath )#">Blog</a>
	<span aria-hidden="true">&rsaquo;</span>
	<span aria-current="page">#encodeForHTML( args.post.getTitle() )#</span>
</p>

<article class="section">
	<h1>#encodeForHTML( args.post.getTitle() )#</h1>
	<cfif !isNull( args.post.getPublishedAt() )>
		<p style="color:##5b6675;font-size:.85rem;font-family:'Inter',sans-serif;margin-top:-.4rem">
			<time datetime="#dateTimeFormat( args.post.getPublishedAt(), 'yyyy-mm-dd' )#">#dateFormat( args.post.getPublishedAt(), "d mmmm yyyy" )#</time>
		</p>
	</cfif>
	#args.post.getContent()#
</article>
</cfoutput>
