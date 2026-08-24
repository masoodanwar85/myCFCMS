<cfoutput>
<h1>Not allowed</h1>
<p class="sub">Your roles on this site do not permit this.</p>
<cfif len( prc.deniedPermission ?: "" )>
	<p class="muted">Required permission: <code>#encodeForHTML( prc.deniedPermission )#</code></p>
<cfelse>
	<p class="muted">This screen declares no permission, so access is refused by default.</p>
</cfif>
<p><a href="/admin">Back to the dashboard</a></p>
</cfoutput>
