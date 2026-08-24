<cfoutput>
<cfset editing = isObject( prc.user )>
<h1>#editing ? "Edit user" : "New user"#</h1>
<p class="sub">#encodeForHTML( prc.currentSite.getName() )#</p>

<form method="post" action="#editing ? '/admin/users/update/' & prc.user.getId() : '/admin/users/create'#">
	<input type="hidden" name="csrfToken" value="#encodeForHTMLAttribute( prc.csrfToken )#">

	<div class="grid2">
		<div>
			<label for="name">Name</label>
			<input type="text" id="name" name="name" required
			       value="#editing ? encodeForHTMLAttribute( prc.user.getName() ) : ''#">
		</div>
		<div>
			<label for="email">Email</label>
			<input type="email" id="email" name="email" required
			       value="#editing ? encodeForHTMLAttribute( prc.user.getEmail() ) : ''#">
		</div>
	</div>

	<div class="grid2">
		<div>
			<label for="password">Password</label>
			<input type="password" id="password" name="password" #editing ? '' : 'required'#>
			<cfif editing><p class="muted" style="font-size:.8rem">Leave blank to keep the current password.</p></cfif>
		</div>
		<div>
			<label for="status">Status</label>
			<select id="status" name="status">
				<cfloop array="#[ 'active', 'inactive' ]#" index="s">
					<option value="#s#" #editing && prc.user.getStatus() eq s ? 'selected' : ''#>#s#</option>
				</cfloop>
			</select>
		</div>
	</div>

	<label>Roles</label>
	<cfif prc.roles.len()>
		<div class="checks">
			<cfloop array="#prc.roles#" index="role">
				<label>
					<input type="checkbox" name="roleIds" value="#role.getId()#"
					       #arrayContains( prc.heldRoles, role.getId() ) ? 'checked' : ''#>
					#encodeForHTML( role.getName() )#
				</label>
			</cfloop>
		</div>
	<cfelse>
		<p class="muted">This site has no roles yet.</p>
	</cfif>

	<div class="actions-bar">
		<button type="submit">#editing ? "Save changes" : "Create user"#</button>
		<a class="btn secondary" href="/admin/users">Cancel</a>
	</div>
</form>
</cfoutput>
