<cfoutput>
<!---
	The page's featured image, above everything else.

	`args.featuredImage` arrives already resolved — the page's own, or the
	nearest ancestor's, or the site default, or empty. The view never needs to
	know that chain; it only asks whether there is a picture.

	`alt=""` on purpose. This is a decorative banner and the heading directly
	below says what the page is, so describing it with the same words would
	have a screen reader announce the title twice.
--->
<cfif len( args.featuredImage ?: "" )>
	<div class="wrap">
		<figure class="page-hero">
			<img src="#xmlFormat( args.featuredImage )#" alt="" loading="eager" decoding="async">
		</figure>
	</div>
</cfif>

<!---
	Breadcrumbs sit above the heading as a quiet line. On a site several levels
	deep they are not decoration: a path like
	/services/probate/probate-nsw/probate-sydney is impossible to place without
	them.
--->
<cfif args.showBreadcrumbs and args.breadcrumb.len() gt 1>
	<div class="wrap">
		<p class="crumbs">
			<cfloop array="#args.breadcrumb#" index="crumb">
				<cfif crumb.getId() neq args.page.getId()>
					<a href="/#xmlFormat( crumb.getPath() )#">#encodeForHTML( crumb.getTitle() )#</a>
					<span aria-hidden="true">&rsaquo;</span>
				<cfelse>
					<span aria-current="page">#encodeForHTML( crumb.getTitle() )#</span>
				</cfif>
			</cfloop>
		</p>
	</div>
</cfif>

<cfif args.page.getShowHeading()>
	<div class="wrap page-head">
		<h1>#encodeForHTML( args.page.getTitle() )#</h1>
	</div>
</cfif>

<section class="section">
	<div class="wrap">
		<!---
			Some pages carry their own headline in the content — a hero, or a
			styled title block — and printing the page title above it says the
			same thing twice. Off by choice, per page, which is why the heading
			above is conditional rather than part of this section.
		--->
		<div>#args.page.getContent()#</div>
	</div>
</section>
</cfoutput>
