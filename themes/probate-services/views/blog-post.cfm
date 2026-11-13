<cfoutput>
<article>
	<cfif args.showBreadcrumbs>
		<div class="wrap">
			<p class="crumbs"><a href="/#xmlFormat( args.basePath )#">Blog</a></p>
		</div>
	</cfif>

	<cfif args.post.getShowHeading()>
		<div class="wrap page-head">
			<h1>#encodeForHTML( args.post.getTitle() )#</h1>
			<cfif !isNull( args.post.getPublishedAt() )>
				<p class="post-meta">
					<time datetime="#dateTimeFormat( args.post.getPublishedAt(), 'yyyy-mm-dd' )#">#dateFormat( args.post.getPublishedAt(), "d mmmm yyyy" )#</time>
				</p>
			</cfif>
		</div>
	</cfif>

	<section class="section">
		<div class="wrap">
			<div class="prose">#args.post.getContent()#</div>

			<cfif args.post.getCategories().len()>
				<div class="tag-row">
					<cfloop array="#args.post.getCategories()#" index="c">
						<a class="tag" href="/#xmlFormat( args.basePath )#/category/#xmlFormat( c.getSlug() )#">#encodeForHTML( c.getName() )#</a>
					</cfloop>
				</div>
			</cfif>
		</div>
	</section>
</article>
</cfoutput>
