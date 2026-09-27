<cfoutput>
<!---
	Resolved upstream: the page's own image, the nearest ancestor's, or none.
	`alt=""` because the heading below already names the page — see the
	willcreator view for the longer note.
--->
<cfif len( args.featuredImage ?: "" )>
	<figure class="page-hero">
		<img src="#xmlFormat( args.featuredImage )#" alt="" loading="eager" decoding="async">
	</figure>
</cfif>

<cfif args.breadcrumb.len() gt 1>
	<p class="crumbs">
		<cfloop array="#args.breadcrumb#" index="crumb">
			<cfif crumb.getId() neq args.page.getId()>
				<a href="/#xmlFormat( crumb.getPath() )#">#encodeForHTML( crumb.getTitle() )#</a> /
			<cfelse>
				#encodeForHTML( crumb.getTitle() )#
			</cfif>
		</cfloop>
	</p>
</cfif>

<article>
	<cfif args.page.getShowHeading()>
		<h1>#encodeForHTML( args.page.getTitle() )#</h1>
	</cfif>
	#args.page.getContent()#
</article>
</cfoutput>
