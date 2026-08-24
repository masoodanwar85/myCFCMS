<cfoutput>
<h1>Pages</h1>
<p class="sub">The content tree for #encodeForHTML( prc.currentSite.getName() )#.</p>

<div class="adm-toolbar">
	<cfif prc.canCreate><a class="btn" href="/admin/pages/new">+ New page</a></cfif>
	<a class="btn secondary" href="/" target="_blank" rel="noopener">View site &nearr;</a>
	<span class="adm-count">#prc.tree.len()# pages</span>
</div>

<table>
	<thead><tr><th style="width:40%">Page</th><th>URL</th><th class="c">Status</th><th class="r">Actions</th></tr></thead>
	<tbody>
		<cfif !prc.tree.len()>
			<tr><td colspan="4" class="muted">No pages yet.</td></tr>
		</cfif>
		<cfloop array="#prc.tree#" index="row">
			<cfset p = row.page>
			<cfset isHome = !isNull( prc.homePage ) && prc.homePage.getId() eq p.getId()>
			<tr class="#p.isPublished() ? '' : 'is-off'#">
				<td>
					<span class="indent" style="padding-left:#row.depth * 22#px"></span>
					<cfif prc.canUpdate>
						<a href="/admin/pages/edit/#p.getId()#"><strong>#encodeForHTML( p.getTitle() )#</strong></a>
					<cfelse>
						<strong>#encodeForHTML( p.getTitle() )#</strong>
					</cfif>
					<cfif isHome><span class="tag">home</span></cfif>
					<cfif p.isArchived()><span class="tag alt">archived</span></cfif>
				</td>
				<td class="mono"><a href="/#xmlFormat( p.getPath() )#" target="_blank" rel="noopener">/#encodeForHTML( p.getPath() )#</a></td>
				<td class="c">
					<!--- Status and the control that changes it are the same
					      thing, so it reads as one fact rather than two. --->
					<cfif prc.canPublish>
						<form class="inline" method="post" action="/admin/pages/#p.isPublished() ? 'unpublish' : 'publish'#/#p.getId()#">
							<input type="hidden" name="csrfToken" value="#encodeForHTMLAttribute( prc.csrfToken )#">
							<button type="submit" class="pill #p.isPublished() ? 'on' : 'off'#"
							        title="#p.isPublished() ? 'Unpublish this page' : 'Publish this page'#">#p.isPublished() ? "Published" : "Draft"#</button>
						</form>
					<cfelse>
						<span class="pill #p.isPublished() ? 'on' : 'off'#">#p.isPublished() ? "Published" : "Draft"#</span>
					</cfif>
				</td>
				<td class="r nowrap">
					<cfif prc.canUpdate><a class="ico" href="/admin/pages/edit/#p.getId()#" title="Edit">Edit</a></cfif>

					<cfif prc.canUpdate && !isHome && p.isPublished()>
						<form class="inline" method="post" action="/admin/pages/setHome/#p.getId()#">
							<input type="hidden" name="csrfToken" value="#encodeForHTMLAttribute( prc.csrfToken )#">
							<button type="submit" class="ico" title="Serve this page at the site root">Set home</button>
						</form>
					</cfif>

					<cfif prc.canDelete>
						<form class="inline" method="post" action="/admin/pages/remove/#p.getId()#"
						      onsubmit="return confirm('Delete #encodeForJavaScript( p.getTitle() )#?')">
							<input type="hidden" name="csrfToken" value="#encodeForHTMLAttribute( prc.csrfToken )#">
							<button type="submit" class="ico danger" title="Delete">Delete</button>
						</form>
					</cfif>
				</td>
			</tr>
		</cfloop>
	</tbody>
</table>
</cfoutput>
