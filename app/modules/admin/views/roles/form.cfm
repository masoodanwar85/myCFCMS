<cfoutput>
<cfset editing = isObject( prc.role )>
<h1>#editing ? "Edit role" : "New role"#</h1>
<p class="sub">Permissions come from the modules installed on this platform.</p>

<form method="post" action="#editing ? '/admin/roles/update/' & prc.role.getId() : '/admin/roles/create'#">
	<input type="hidden" name="csrfToken" value="#encodeForHTMLAttribute( prc.csrfToken )#">

	<div class="grid2">
		<div>
			<label for="name">Name</label>
			<input type="text" id="name" name="name" required
			       value="#editing ? encodeForHTMLAttribute( prc.role.getName() ) : ''#">
		</div>
		<div>
			<label for="slug">Slug</label>
			<cfif editing>
				<input type="text" id="slug" value="#encodeForHTMLAttribute( prc.role.getSlug() )#" disabled>
				<p class="muted" style="font-size:.8rem">A role's slug is fixed once created.</p>
			<cfelse>
				<input type="text" id="slug" name="slug" placeholder="derived from the name">
			</cfif>
		</div>
	</div>

	<label for="description">Description</label>
	<input type="text" id="description" name="description"
	       value="#editing ? encodeForHTMLAttribute( prc.role.getDescription() ?: '' ) : ''#">

	<label>Permissions</label>
	<div class="checks">
		<cfloop array="#prc.permissions#" index="permission">
			<label title="#encodeForHTMLAttribute( permission.getDescription() ?: '' )#">
				<input type="checkbox" name="permissionSlugs" value="#encodeForHTMLAttribute( permission.getSlug() )#"
				       #arrayContains( prc.held, permission.getSlug() ) ? 'checked' : ''#>
				<span><code>#encodeForHTML( permission.getSlug() )#</code></span>
			</label>
		</cfloop>
	</div>

	<div class="actions-bar">
		<button type="submit">#editing ? "Save changes" : "Create role"#</button>
		<a class="btn secondary" href="/admin/roles">Cancel</a>
	</div>
</form>
</cfoutput>
