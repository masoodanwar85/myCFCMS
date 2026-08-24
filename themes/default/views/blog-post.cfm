<cfoutput>
<article>
	<p class="crumbs"><a href="/#xmlFormat( args.basePath )#">Blog</a></p>

	<h1>#encodeForHTML( args.post.getTitle() )#</h1>

	<cfif !isNull( args.post.getPublishedAt() )>
		<p style="color:##666;font-size:.85rem;margin:0 0 1.5rem">
			<time datetime="#dateTimeFormat( args.post.getPublishedAt(), 'yyyy-mm-dd' )#">#dateFormat( args.post.getPublishedAt(), "d mmmm yyyy" )#</time>
		</p>
	</cfif>

	#args.post.getContent()#

	<cfif args.post.getCategories().len()>
		<p style="margin-top:2rem;color:##666;font-size:.85rem">
			Filed under:
			<cfloop array="#args.post.getCategories()#" index="c">
				<a href="/#xmlFormat( args.basePath )#/category/#xmlFormat( c.getSlug() )#">#encodeForHTML( c.getName() )#</a>
			</cfloop>
		</p>
	</cfif>
</article>
</cfoutput>
