<cfoutput>
<h1>Users</h1>
<p class="sub">People who can sign in to #encodeForHTML( prc.currentSite.getName() )#.</p>

<div class="adm-toolbar">
	<cfif prc.canCreate><a class="btn" href="/admin/users/new">+ New user</a></cfif>
	<span class="adm-count">#prc.pagination.total# users</span>
</div>

<table>
	<thead>
		<tr><th>Name</th><th>Email</th><th>Roles</th><th class="c">Status</th><th class="r">Actions</th></tr>
	</thead>
	<tbody>
		<cfif !prc.users.len()>
			<tr><td colspan="5" class="muted">No users yet.</td></tr>
		</cfif>
		<cfloop array="#prc.users#" index="u">
			<tr class="#u.isActive() ? '' : 'is-off'#">
				<td><strong>#encodeForHTML( u.getName() )#</strong></td>
				<td>#encodeForHTML( u.getEmail() )#</td>
				<td>
					<cfif prc.roleNames[ u.getId() ].len()>
						#encodeForHTML( prc.roleNames[ u.getId() ].toList( ", " ) )#
					<cfelse>
						<span class="muted">none</span>
					</cfif>
				</td>
				<td class="c"><span class="pill #u.isActive() ? 'on' : 'off'#">#encodeForHTML( u.getStatus() )#</span></td>
				<td class="r nowrap">
					<cfif prc.canUpdate><a class="ico" href="/admin/users/edit/#u.getId()#" title="Edit">Edit</a></cfif>
					<cfif prc.canDelete && u.getId() neq prc.currentUser.getId()>
						<form class="inline" method="post" action="/admin/users/remove/#u.getId()#"
						      onsubmit="return confirm('Delete #encodeForJavaScript( u.getName() )#?')">
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

</cfoutput>
