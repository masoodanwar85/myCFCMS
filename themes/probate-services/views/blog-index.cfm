<cfoutput>
<section class="section">
	<div class="wrap">
		<div class="stack" style="margin-bottom:32px">
			<span class="eyebrow">Writing</span>
			<h1><cfif isObject( args.category )>#encodeForHTML( args.category.getName() )#<cfelse>Articles and updates</cfif></h1>
			<cfif isObject( args.category ) && len( args.category.getDescription() ?: "" )>
				<p class="lead">#encodeForHTML( args.category.getDescription() )#</p>
			</cfif>
		</div>

		<cfif !args.posts.len()>
			<p class="lead">Nothing has been published yet.</p>
		</cfif>

		<div class="post-list">
			<cfloop array="#args.posts#" index="post">
				<article class="post-item">
					<h2><a href="/#xmlFormat( args.basePath )#/#xmlFormat( post.getSlug() )#">#encodeForHTML( post.getTitle() )#</a></h2>
					<cfif !isNull( post.getPublishedAt() )>
						<p class="post-meta">
							<time datetime="#dateTimeFormat( post.getPublishedAt(), 'yyyy-mm-dd' )#">#dateFormat( post.getPublishedAt(), "d mmmm yyyy" )#</time>
						</p>
					</cfif>
					<p>#encodeForHTML( post.getEffectiveExcerpt() )#</p>
				</article>
			</cfloop>
		</div>

		<cfif ( args.pagination.totalPages ?: 0 ) gt 1>
			<nav class="pager" aria-label="Archive pages">
				<cfif args.pagination.hasPrevious>
					<a href="#xmlFormat( args.pageBase & ( args.pagination.previousPage gt 1 ? '/page/' & args.pagination.previousPage : '' ) )#" rel="prev">Newer</a>
				<cfelse>
					<span>Newer</span>
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
				<cfelse>
					<span>Older</span>
				</cfif>
			</nav>
		</cfif>

		<cfif args.categories.len()>
			<h2 style="font-size:20px;margin-top:48px">Categories</h2>
			<div class="tag-row">
				<cfloop array="#args.categories#" index="c">
					<a class="tag" href="/#xmlFormat( args.basePath )#/category/#xmlFormat( c.getSlug() )#">#encodeForHTML( c.getName() )# (#c.getPostCount()#)</a>
				</cfloop>
			</div>
		</cfif>
	</div>
</section>
</cfoutput>
