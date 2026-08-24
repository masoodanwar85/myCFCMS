<cfoutput>
<cfset editing = isObject( prc.post )>
<h1>#editing ? "Edit post" : "New post"#</h1>
<cfif editing><p class="sub"><code>/blog/#encodeForHTML( prc.post.getSlug() )#</code></p></cfif>

<form method="post" action="#editing ? '/admin/blog/update/' & prc.post.getId() : '/admin/blog/create'#">
	<input type="hidden" name="csrfToken" value="#encodeForHTMLAttribute( prc.csrfToken )#">

	<div class="grid2">
		<div>
			<label for="title">Title</label>
			<input type="text" id="title" name="title" required
			       value="#editing ? encodeForHTMLAttribute( prc.post.getTitle() ) : ''#">
		</div>
		<div>
			<label for="slug">Slug</label>
			<input type="text" id="slug" name="slug" placeholder="derived from the title"
			       value="#editing ? encodeForHTMLAttribute( prc.post.getSlug() ) : ''#">
		</div>
	</div>

	<label for="excerpt">Excerpt</label>
	<input type="text" id="excerpt" name="excerpt" placeholder="Optional; taken from the content when blank"
	       value="#editing ? encodeForHTMLAttribute( prc.post.getExcerpt() ?: '' ) : ''#">

	<label for="content">Content</label>
	<textarea id="content" name="content" data-editor>#editing ? encodeForHTML( prc.post.getContent() ?: "" ) : ""#</textarea>

	<label>Categories</label>
	<cfif prc.categories.len()>
		<div class="checks">
			<cfloop array="#prc.categories#" index="c">
				<label>
					<input type="checkbox" name="categoryIds" value="#c.getId()#"
					       #arrayContains( prc.selected, c.getId() ) ? 'checked' : ''#>
					#encodeForHTML( c.getName() )#
				</label>
			</cfloop>
		</div>
	<cfelse>
		<p class="muted">No categories yet.</p>
	</cfif>

	<div class="grid2">
		<div>
			<label for="metaTitle">Meta title</label>
			<input type="text" id="metaTitle" name="metaTitle"
			       value="#editing ? encodeForHTMLAttribute( prc.post.getMetaTitle() ?: '' ) : ''#">
		</div>
		<div>
			<label for="metaDescription">Meta description</label>
			<input type="text" id="metaDescription" name="metaDescription"
			       value="#editing ? encodeForHTMLAttribute( prc.post.getMetaDescription() ?: '' ) : ''#">
		</div>
	</div>

	<div class="actions-bar">
		<button type="submit">#editing ? "Save post" : "Create post"#</button>
		<a class="btn secondary" href="/admin/blog">Cancel</a>
	</div>
</form>
</cfoutput>
