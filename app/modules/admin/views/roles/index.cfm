<cfoutput>
<h1>Roles</h1>
<p class="sub">What each group of people on this site is allowed to do.</p>

<div class="adm-toolbar">
	<cfif prc.canCreate><a class="btn" href="/admin/roles/new">+ New role</a></cfif>
	<span class="adm-count">#prc.roles.len()# roles</span>
</div>

<table>
	<thead><tr><th style="width:26%">Role</th><th>Permissions</th><th class="r">Actions</th></tr></thead>
	<tbody>
		<cfif !prc.roles.len()>
			<tr><td colspan="3" class="muted">No roles yet.</td></tr>
		</cfif>
		<cfloop array="#prc.roles#" index="role">
			<tr>
				<td>
					<strong>#encodeForHTML( role.getName() )#</strong>
					<div class="muted" style="font-size:.8rem">#encodeForHTML( role.getSlug() )#</div>
				</td>
				<td>
					<cfset slugs = prc.granted[ role.getId() ]>
					<cfif slugs.len()>
						#encodeForHTML( slugs.len() )# granted
						<div class="muted" style="font-size:.78rem">#encodeForHTML( slugs.toList( ", " ) )#</div>
					<cfelse>
						<span class="muted">none</span>
					</cfif>
				</td>
				<td class="r nowrap">
					<cfif prc.canUpdate><a class="ico" href="/admin/roles/edit/#role.getId()#" title="Edit">Edit</a></cfif>
					<cfif prc.canDelete>
						<form class="inline" method="post" action="/admin/roles/remove/#role.getId()#"
						      onsubmit="return confirm('Delete #encodeForJavaScript( role.getName() )#?')">
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
