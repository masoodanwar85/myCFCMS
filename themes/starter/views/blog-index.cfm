<cfoutput>
<article data-view="starter-blog-index">
	<h1><cfif isObject( args.category )>#encodeForHTML( args.category.getName() )#<cfelse>Journal</cfif></h1>
	<cfif !args.posts.len()><p>Nothing written yet.</p></cfif>
	<cfloop array="#args.posts#" index="post">
		<section>
			<h2><a href="/#xmlFormat( args.basePath )#/#xmlFormat( post.getSlug() )#">#encodeForHTML( post.getTitle() )#</a></h2>
			<p>#encodeForHTML( post.getEffectiveExcerpt( 140 ) )#</p>
		</section>
	</cfloop>
	<cfif ( args.pagination.totalPages ?: 0 ) gt 1>
		<nav aria-label="Archive pages" style="margin-top:2rem">
			<cfif args.pagination.hasPrevious>
				<a href="#xmlFormat( args.pageBase & ( args.pagination.previousPage gt 1 ? '/page/' & args.pagination.previousPage : '' ) )#" rel="prev">&larr; Newer</a>
			</cfif>
			<span style="margin:0 .5rem">Page #args.pagination.page# of #args.pagination.totalPages#</span>
			<cfif args.pagination.hasNext>
				<a href="#xmlFormat( args.pageBase & '/page/' & args.pagination.nextPage )#" rel="next">Older &rarr;</a>
			</cfif>
		</nav>
	</cfif>
</article>
</cfoutput>
