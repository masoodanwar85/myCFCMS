<cfoutput>
<h1>API activity</h1>
<p class="sub">
	Every change made through the REST API on
	#encodeForHTML( prc.currentSite.getName() )#, newest first. Changes made in
	these admin screens are not listed &mdash; those carry a sign-in, not a token.
</p>

<div class="adm-toolbar">
	<form class="inline" method="get" action="/admin/api-activity">
		<select name="type" onchange="this.form.submit()">
			<option value=""<cfif !len( prc.type )> selected</cfif>>Everything</option>
			<cfloop array="#prc.types#" index="kind">
				<option value="#encodeForHTMLAttribute( kind )#"<cfif prc.type eq kind> selected</cfif>>#encodeForHTML( kind )#s</option>
			</cfloop>
		</select>
		<noscript><button type="submit" class="btn secondary">Filter</button></noscript>
	</form>
	<a class="btn secondary" href="/admin/api-tokens">Tokens</a>
	<span class="adm-count">#prc.pagination.total# change#prc.pagination.total eq 1 ? "" : "s"#</span>
</div>

<table>
	<thead>
		<tr>
			<th>When</th><th>Who</th><th>Token</th><th>Action</th>
			<th>Resource</th><th>Changed</th>
		</tr>
	</thead>
	<tbody>
		<cfif !prc.changes.len()>
			<tr>
				<td colspan="6" class="muted">
					<cfif len( prc.type )>
						Nothing has changed a #encodeForHTML( prc.type )# through the API yet.
					<cfelse>
						Nothing has been changed through the API yet.
					</cfif>
				</td>
			</tr>
		</cfif>
		<cfloop array="#prc.changes#" index="change">
			<cfset changed = change.changedFields()>
			<tr>
				<td>#dateTimeFormat( change.getCreatedAt(), "d mmm yyyy, HH:nn:ss" )#</td>
				<td>
					<cfif len( change.getUserName() )>
						#encodeForHTML( change.getUserName() )#
					<cfelse>
						<!--- The user was deleted. The change outlives them, which is the point. --->
						<span class="muted">deleted user</span>
					</cfif>
				</td>
				<td>
					<cfif len( change.getTokenName() )>
						<code>#encodeForHTML( change.getTokenName() )#</code>
					<cfelse>
						<span class="muted">&mdash;</span>
					</cfif>
				</td>
				<td><span class="pill #change.getAction() eq 'delete' ? 'off' : 'on'#">#encodeForHTML( change.getAction() )#</span></td>
				<td>
					#encodeForHTML( change.getResourceType() )#
					<cfif !isNull( change.getResourceId() )>
						<cfif change.getResourceType() eq "page">
							<a href="/admin/pages/edit/#change.getResourceId()#">###change.getResourceId()#</a>
						<cfelse>
							<span class="muted">###change.getResourceId()#</span>
						</cfif>
					</cfif>
				</td>
				<td>
					<cfif changed.len()>
						<details>
							<summary>#changed.len()# field#changed.len() eq 1 ? "" : "s"#</summary>
							<p class="muted" style="margin:.4rem 0">#encodeForHTML( changed.toList( ", " ) )#</p>
							<!--- The full snapshots, for when the question is what it
							      actually said rather than which field moved. A delete
							      has only a `before`, and that is the whole value of
							      the entry: nothing else records what the page said. --->
							<cfif len( change.getBeforeJson() ) gt 2>
								<p style="margin:.4rem 0 .2rem"><strong>Before</strong></p>
								<pre style="max-height:16rem; overflow:auto; font-size:.75rem">#encodeForHTML( change.getBeforeJson() )#</pre>
							</cfif>
							<cfif len( change.getAfterJson() ) gt 2>
								<p style="margin:.4rem 0 .2rem"><strong>After</strong></p>
								<pre style="max-height:16rem; overflow:auto; font-size:.75rem">#encodeForHTML( change.getAfterJson() )#</pre>
							</cfif>
						</details>
					<cfelse>
						<span class="muted">nothing</span>
					</cfif>
				</td>
			</tr>
		</cfloop>
	</tbody>
</table>

<cfinclude template="/core/views/_pagination.cfm">
</cfoutput>
