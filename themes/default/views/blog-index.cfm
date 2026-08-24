<cfoutput>
<article>
	<h1><cfif isObject( args.category )>#encodeForHTML( args.category.getName() )#<cfelse>Blog</cfif></h1>

	<cfif isObject( args.category ) && len( args.category.getDescription() ?: "" )>
		<p class="muted">#encodeForHTML( args.category.getDescription() )#</p>
	</cfif>

	<cfif !args.posts.len()>
		<p>No posts yet.</p>
	</cfif>

	<cfloop array="#args.posts#" index="post">
		<section style="margin:0 0 2rem;padding:0 0 1.25rem;border-bottom:1px solid ##e5e5e5">
			<h2 style="margin:0 0 .25rem;font-size:1.25rem">
				<a href="/#xmlFormat( args.basePath )#/#xmlFormat( post.getSlug() )#">#encodeForHTML( post.getTitle() )#</a>
			</h2>
			<cfif !isNull( post.getPublishedAt() )>
				<p style="margin:0 0 .5rem;color:##666;font-size:.85rem">
					<time datetime="#dateTimeFormat( post.getPublishedAt(), 'yyyy-mm-dd' )#">#dateFormat( post.getPublishedAt(), "d mmmm yyyy" )#</time>
				</p>
			</cfif>
			<p style="margin:0">#encodeForHTML( post.getEffectiveExcerpt() )#</p>
		</section>
	</cfloop>

	<cfif ( args.pagination.totalPages ?: 0 ) gt 1>
		<nav aria-label="Archive pages" style="margin:2rem 0;display:flex;gap:.4rem;align-items:center;flex-wrap:wrap">
			<cfif args.pagination.hasPrevious>
				<a href="#xmlFormat( args.pageBase & ( args.pagination.previousPage gt 1 ? '/page/' & args.pagination.previousPage : '' ) )#" rel="prev">Newer</a>
			<cfelse>
				<span style="color:##999">Newer</span>
			</cfif>

			<cfloop array="#args.pagination.pages#" index="n">
				<cfif n eq 0>
					<span style="color:##999">&hellip;</span>
				<cfelseif n eq args.pagination.page>
					<strong aria-current="page">#n#</strong>
				<cfelse>
					<a href="#xmlFormat( args.pageBase & ( n gt 1 ? '/page/' & n : '' ) )#">#n#</a>
				</cfif>
			</cfloop>

			<cfif args.pagination.hasNext>
				<a href="#xmlFormat( args.pageBase & '/page/' & args.pagination.nextPage )#" rel="next">Older</a>
			<cfelse>
				<span style="color:##999">Older</span>
			</cfif>
		</nav>
	</cfif>

	<cfif args.categories.len()>
		<h2 style="font-size:1rem">Categories</h2>
		<p>
			<cfloop array="#args.categories#" index="c">
				<a href="/#xmlFormat( args.basePath )#/category/#xmlFormat( c.getSlug() )#">#encodeForHTML( c.getName() )#</a>
				<span style="color:##666">(#c.getPostCount()#)</span>&nbsp;
			</cfloop>
		</p>
	</cfif>
</article>
</cfoutput>
