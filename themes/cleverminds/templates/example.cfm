<cfoutput>
<!---
	An example page template.

	A page picks this from the Template dropdown on its Advanced tab, and the
	theme renders it instead of `views/page.cfm`. Copy it, rename it, and the
	new name appears in that dropdown — the picker lists whatever `.cfm` files
	are in this directory, so there is nothing to register.

	## What a template gets

	The same `args` a view gets, plus everything the resolver passed:

	    args.page        the Page entity — title, content, SEO fields, dates
	    args.breadcrumb  its ancestors, for a trail
	    args.site        the Site
	    args.theme       this theme, for `assetUrl()`

	The page's title, slug, SEO settings, menu position and publish window all
	behave exactly as they do for an ordinary page. A template changes how the
	body is drawn, nothing else.

	## What a template may do

	It is ordinary CFML running on the server, so it can reach any service:

	    <cfset local.blog = application.wirebox.getInstance( "BlogService@blog" )>
	    <cfset local.recent = local.blog.getPublishedPosts( args.site.getId(), 3, 0 )>

	Prefer a shortcode for a fragment that belongs inside prose an author is
	writing, and a module with its own resolver when the thing is an application
	rather than a page. A template is the middle case: one page, its own layout
	and logic, written by a developer and chosen by an author.

	## Why the code is here and not in the database

	Anything an author could type and the server would execute would run as the
	ColdFusion user with the application's datasource — which on a multi-tenant
	install means one client's editor could read every other client's data. Code
	lives in the theme, deployed by whoever deploys code. The author chooses
	from what exists.
--->
<article data-template="example">
	<cfif args.page.getShowHeading()>
		<h1>#encodeForHTML( args.page.getTitle() )#</h1>
	</cfif>

	#args.page.getContent()#
	
	<hr>
	<p class="muted">
		Rendered by the <strong>example</strong> template rather than the standard page view.
		Last updated #dateFormat( args.page.getUpdatedAt(), "d mmmm yyyy" )#.
	</p>
</article>
</cfoutput>
