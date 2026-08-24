<cfoutput>
<h1>API tokens</h1>
<p class="sub">
	Credentials for the REST API at <code>/api/v1</code>, for
	#encodeForHTML( prc.currentSite.getName() )#.
</p>

<cfif len( prc.newToken )>
	<div class="flash">
		<p style="margin:0 0 .4rem"><strong>#encodeForHTML( prc.newName )#</strong> — copy this now. It cannot be shown again.</p>
		<code style="display:block; padding:.5rem; word-break:break-all; font-size:.85rem">#encodeForHTML( prc.newToken )#</code>
	</div>
</cfif>

<div class="adm-toolbar">
	<a class="btn secondary" href="/api/v1" target="_blank" rel="noopener">API root &nearr;</a>
	<span class="adm-count">#prc.tokens.len()# token#prc.tokens.len() eq 1 ? "" : "s"#</span>
</div>

<table>
	<thead>
		<tr>
			<th>Name</th><th>Token</th><th>Acts as</th><th>Last used</th>
			<th class="c">Status</th><th class="r">Actions</th>
		</tr>
	</thead>
	<tbody>
		<cfif !prc.tokens.len()>
			<tr><td colspan="6" class="muted">No tokens yet.</td></tr>
		</cfif>
		<cfloop array="#prc.tokens#" index="token">
			<tr<cfif !token.isActive()> class="is-off"</cfif>>
				<td><strong>#encodeForHTML( token.getName() )#</strong></td>
				<td><code>#encodeForHTML( token.getMasked() )#</code></td>
				<td>
					<cfset owner = prc.users.filter( ( u ) => u.getId() == token.getUserId() )>
					<cfif owner.len()>#encodeForHTML( owner[ 1 ].getName() )#<cfelse><span class="muted">&mdash;</span></cfif>
				</td>
				<td>
					<cfif isNull( token.getLastUsedAt() )>
						<span class="muted">never</span>
					<cfelse>
						#dateTimeFormat( token.getLastUsedAt(), "d mmm yyyy, HH:nn" )#
					</cfif>
				</td>
				<td class="c">
					<span class="pill #token.getStatus() eq 'active' ? 'on' : 'off'#">#token.getStatus()#</span>
				</td>
				<td class="actions">
					<cfif token.isActive()>
						<form class="inline" method="post" action="/admin/api-tokens/revoke/#token.getId()#"
						      onsubmit="return confirm('Revoke #encodeForJavaScript( token.getName() )#? Anything using it stops working immediately.')">
							<input type="hidden" name="csrfToken" value="#encodeForHTMLAttribute( prc.csrfToken )#">
							<button type="submit" class="ico">Revoke</button>
						</form>
					</cfif>
					<form class="inline" method="post" action="/admin/api-tokens/remove/#token.getId()#"
					      onsubmit="return confirm('Delete this token record?')">
						<input type="hidden" name="csrfToken" value="#encodeForHTMLAttribute( prc.csrfToken )#">
						<button type="submit" class="ico danger">Delete</button>
					</form>
				</td>
			</tr>
		</cfloop>
	</tbody>
</table>

<h2>Issue a token</h2>
<form method="post" action="/admin/api-tokens/issue">
	<input type="hidden" name="csrfToken" value="#encodeForHTMLAttribute( prc.csrfToken )#">

	<div class="grid2">
		<div>
			<label for="name">Name</label>
			<input type="text" id="name" name="name" required placeholder="Deploy pipeline">
			<p class="muted" style="font-size:.8rem">So you can recognise it later. Only you will see this.</p>
		</div>
		<div>
			<label for="userId">Acts as</label>
			<select id="userId" name="userId" required>
				<cfloop array="#prc.users#" index="user">
					<option value="#user.getId()#">#encodeForHTML( user.getName() )# &mdash; #encodeForHTML( user.getEmail() )#</option>
				</cfloop>
			</select>
			<p class="muted" style="font-size:.8rem">
				The token can never do more than this person can. Removing their access removes the token's.
			</p>
		</div>
	</div>

	<label for="expiresAt">Expires</label>
	<input type="date" id="expiresAt" name="expiresAt">
	<p class="muted" style="font-size:.8rem">
		Optional, and worth setting. A token with no expiry outlives everyone who remembers creating it.
	</p>

	<div class="actions-bar"><button type="submit">Issue token</button></div>
</form>
</cfoutput>
