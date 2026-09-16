<cfoutput>
<!---
	Breadcrumbs sit outside the white card, as a quiet line above it. On a site
	four levels deep they are not decoration: `/legal-services/wills/wills-blue-mountains/wills-katoomba`
	is impossible to place without them.
--->
<cfif args.breadcrumb.len() gt 1>
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

<section class="section">
	<div class="wrap">
		<!---
			Some pages carry their own headline in the content — a hero, or a
			styled title block — and printing the page title above it says the
			same thing twice. Off by choice, per page.
		--->
		<cfif args.page.getShowHeading()>
			<h1>#encodeForHTML( args.page.getTitle() )#</h1>
		</cfif>
		#args.page.getContent()#
	</div>
</section>
</cfoutput>
