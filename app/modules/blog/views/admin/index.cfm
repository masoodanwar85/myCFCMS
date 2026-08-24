<cfoutput>
<h1>Blog</h1>
<p class="sub">Posts and categories for #encodeForHTML( prc.currentSite.getName() )#.</p>

<div class="adm-toolbar">
	<cfif prc.canCreate><a class="btn" href="/admin/blog/new">+ New post</a></cfif>
	<a class="btn secondary" href="/blog" target="_blank" rel="noopener">View blog &nearr;</a>
	<span class="adm-count">#prc.pagination.total# posts</span>
</div>

<table>
	<thead><tr><th style="width:38%">Post</th><th>URL</th><th>Published</th><th class="c">Status</th><th class="r">Actions</th></tr></thead>
	<tbody>
		<cfif !prc.posts.len()>
			<tr><td colspan="5" class="muted">No posts yet.</td></tr>
		</cfif>
		<cfloop array="#prc.posts#" index="post">
			<tr class="#post.isPublished() ? '' : 'is-off'#">
				<td>
					<cfif prc.canUpdate>
						<a href="/admin/blog/edit/#post.getId()#"><strong>#encodeForHTML( post.getTitle() )#</strong></a>
					<cfelse>
						<strong>#encodeForHTML( post.getTitle() )#</strong>
					</cfif>
				</td>
				<td class="mono"><a href="/blog/#xmlFormat( post.getSlug() )#" target="_blank" rel="noopener">/blog/#encodeForHTML( post.getSlug() )#</a></td>
				<td class="muted">
					<cfif !isNull( post.getPublishedAt() )>#dateFormat( post.getPublishedAt(), "d mmm yyyy" )#<cfelse>&mdash;</cfif>
				</td>
				<td class="c">
					<cfif prc.canPublish>
						<form class="inline" method="post" action="/admin/blog/#post.isPublished() ? 'unpublish' : 'publish'#/#post.getId()#">
							<input type="hidden" name="csrfToken" value="#encodeForHTMLAttribute( prc.csrfToken )#">
							<button type="submit" class="pill #post.isPublished() ? 'on' : 'off'#"
							        title="#post.isPublished() ? 'Unpublish' : 'Publish'#">#post.isPublished() ? "Published" : "Draft"#</button>
						</form>
					<cfelse>
						<span class="pill #post.isPublished() ? 'on' : 'off'#">#post.isPublished() ? "Published" : "Draft"#</span>
					</cfif>
				</td>
				<td class="r nowrap">
					<cfif prc.canUpdate><a class="ico" href="/admin/blog/edit/#post.getId()#" title="Edit">Edit</a></cfif>
					<cfif prc.canDelete>
						<form class="inline" method="post" action="/admin/blog/remove/#post.getId()#"
						      onsubmit="return confirm('Delete #encodeForJavaScript( post.getTitle() )#?')">
							<input type="hidden" name="csrfToken" value="#encodeForHTMLAttribute( prc.csrfToken )#">
							<button type="submit" class="ico danger" title="Delete">Delete</button>
						</form>
					</cfif>
				</td>
			</tr>
		</cfloop>
	</tbody>
</table>


<cfinclude template="/core/views/_pagination.cfm">

<h2>Categories</h2>
<table>
	<thead><tr><th>Name</th><th>Slug</th><th>Published posts</th><th></th></tr></thead>
	<tbody>
		<cfif !prc.categories.len()>
			<tr><td colspan="4" class="muted">No categories yet.</td></tr>
		</cfif>
		<cfloop array="#prc.categories#" index="c">
			<tr>
				<td>#encodeForHTML( c.getName() )#</td>
				<td><code>#encodeForHTML( c.getSlug() )#</code></td>
				<td>#c.getPostCount()#</td>
				<td class="actions">
					<cfif prc.canManageCategories>
						<form class="inline" method="post" action="/admin/blog/removeCategory/#c.getId()#"
						      onsubmit="return confirm('Delete #encodeForJavaScript( c.getName() )#? Posts keep their content.')">
							<input type="hidden" name="csrfToken" value="#encodeForHTMLAttribute( prc.csrfToken )#">
							<button type="submit" class="ico danger">Delete</button>
						</form>
					</cfif>
				</td>
			</tr>
		</cfloop>
	</tbody>
</table>

<cfif prc.canManageCategories>
	<form class="narrow" method="post" action="/admin/blog/createCategory">
		<input type="hidden" name="csrfToken" value="#encodeForHTMLAttribute( prc.csrfToken )#">
		<label for="name">Add a category</label>
		<input type="text" id="name" name="name" placeholder="Announcements" required>
		<div class="actions-bar"><button type="submit">Add category</button></div>
	</form>
</cfif>
</cfoutput>
