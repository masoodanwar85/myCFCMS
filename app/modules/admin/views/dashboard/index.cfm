<cfoutput>
<h1>Dashboard</h1>
<p class="sub">#encodeForHTML( prc.currentSite.getName() )# &middot; #encodeForHTML( prc.currentSite.getStatus() )#</p>

<table>
	<tr><th>Site</th><td>#encodeForHTML( prc.currentSite.getName() )# <span class="muted">(#encodeForHTML( prc.currentSite.getSlug() )#)</span></td></tr>
	<tr><th>Timezone</th><td>#encodeForHTML( prc.currentSite.getTimezone() )#</td></tr>
	<tr><th>Locale</th><td>#encodeForHTML( prc.currentSite.getLocale() )#</td></tr>
	<tr>
		<th>Domains</th>
		<td>
			<cfloop array="#prc.domains#" index="d">
				<code>#encodeForHTML( d.getDomain() )#</code><cfif d.getIsPrimary()> <span class="pill">primary</span></cfif>
				<cfif !d.getIsActive()> <span class="pill">inactive</span></cfif><br>
			</cfloop>
		</td>
	</tr>
	<cfif prc.canSeeUsers><tr><th>Users</th><td>#prc.userCount#</td></tr></cfif>
	<cfif prc.canSeeRoles><tr><th>Roles</th><td>#prc.roleCount#</td></tr></cfif>
</table>

<h2>Your permissions</h2>
<cfif prc.currentUser.isSuperAdmin()>
	<p class="muted">You are a platform super admin: every permission on every site.</p>
<cfelseif prc.permissions.len()>
	<p><cfloop array="#prc.permissions#" index="slug"><code>#encodeForHTML( slug )#</code> </cfloop></p>
<cfelse>
	<p class="muted">No roles have been assigned to you yet.</p>
</cfif>
</cfoutput>
