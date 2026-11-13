<cfoutput>
<article class="section">
	<h1><cfif isObject( args.category )>#encodeForHTML( args.category.getName() )#<cfelse>Blog</cfif></h1>

	<cfif isObject( args.category ) && len( args.category.getDescription() ?: "" )>
		<p>#encodeForHTML( args.category.getDescription() )#</p>
	</cfif>

	<cfif !args.posts.len()>
		<p>No posts yet.</p>
	</cfif>

	<cfloop array="#args.posts#" index="post">
		<section style="margin:0 0 2rem;padding:0 0 1.5rem;border-bottom:1px solid ##e6e1d6">
			<h2 style="margin:0 0 .25rem">
				<a href="/#xmlFormat( args.basePath )#/#xmlFormat( post.getSlug() )#">#encodeForHTML( post.getTitle() )#</a>
			</h2>
			<cfif !isNull( post.getPublishedAt() )>
				<p style="margin:0 0 .6rem;color:##5b6675;font-size:.85rem;font-family:'Inter',sans-serif">
					<time datetime="#dateTimeFormat( post.getPublishedAt(), 'yyyy-mm-dd' )#">#dateFormat( post.getPublishedAt(), "d mmmm yyyy" )#</time>
				</p>
			</cfif>
			<p style="margin:0">#encodeForHTML( post.getEffectiveExcerpt() )#</p>
		</section>
	</cfloop>

	<cfif ( args.pagination.totalPages ?: 0 ) gt 1>
		<nav aria-label="Archive pages" style="margin:2rem 0;display:flex;gap:.5rem;flex-wrap:wrap;align-items:center">
			<cfif args.pagination.hasPrevious>
				<a href="#xmlFormat( args.pageBase & ( args.pagination.previousPage gt 1 ? '/page/' & args.pagination.previousPage : '' ) )#" rel="prev">Newer</a>
			</cfif>
			<cfloop array="#args.pagination.pages#" index="n">
				<cfif n eq 0>
					<span>&hellip;</span>
				<cfelseif n eq args.pagination.page>
					<strong aria-current="page">#n#</strong>
				<cfelse>
					<a href="#xmlFormat( args.pageBase & ( n gt 1 ? '/page/' & n : '' ) )#">#n#</a>
				</cfif>
			</cfloop>
			<cfif args.pagination.hasNext>
				<a href="#xmlFormat( args.pageBase & '/page/' & args.pagination.nextPage )#" rel="next">Older</a>
			</cfif>
		</nav>
	</cfif>
</article>
</cfoutput>
