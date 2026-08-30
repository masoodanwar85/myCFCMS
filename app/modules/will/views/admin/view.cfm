<cfset s = prc.submission>
<cfset local.dobDisplay = "">
<cfif !isNull( s.getWmDob() ) && isDate( s.getWmDob() )>
	<cfset local.dobDisplay = dateFormat( s.getWmDob(), "dd/mm/yyyy" )>
</cfif>
<cfoutput>
<h1>Will</h1>
<p class="sub">Received #dateTimeFormat( s.getCreatedAt(), "d mmmm yyyy, HH:nn" )#</p>

<h2>Will maker</h2>
<table>
	<tr><th>Name</th><td>#encodeForHTML( s.getWmFullname() )#</td></tr>
	<tr><th>Date of birth</th><td>#encodeForHTML( local.dobDisplay )#</td></tr>
	<tr><th>Marital status</th><td>#encodeForHTML( s.getWmMarital() )#</td></tr>
	<tr><th>Address</th><td>#encodeForHTML( s.getWmAddress() )#</td></tr>
	<tr>
		<th>Email</th>
		<td><a href="#xmlFormat( 'mailto:' & s.getWmEmail() )#">#encodeForHTML( s.getWmEmail() )#</a></td>
	</tr>
	<tr><th>Phone</th><td>#encodeForHTML( s.getWmPhone() )#</td></tr>
</table>

<h2>Executor</h2>
<table>
	<tr><th>Name</th><td>#encodeForHTML( s.getExName() )#</td></tr>
	<tr><th>Address</th><td>#encodeForHTML( s.getExAddress() )#</td></tr>
	<tr><th>Relationship</th><td>#encodeForHTML( s.getExRelationship() )#</td></tr>
	<tr><th>Email</th><td>#encodeForHTML( s.getExEmail() )#</td></tr>
	<tr><th>Phone</th><td>#encodeForHTML( s.getExPhone() )#</td></tr>
	<tr><th>May charge fees</th><td>#s.getExCanChargeFees() ? "Yes" : "No"#</td></tr>
	<tr><th>Act jointly / severally</th><td>#encodeForHTML( s.getExActMode() )#</td></tr>
</table>

<cfif prc.related.substituteExecutors.len()>
	<h2>Substitute executors</h2>
	<table>
		<thead><tr><th>Name</th><th>Relationship</th><th>Email</th><th>Phone</th></tr></thead>
		<tbody>
			<cfloop array="#prc.related.substituteExecutors#" index="row">
				<tr>
					<td>#encodeForHTML( row.getExName() )#</td>
					<td>#encodeForHTML( row.getExRelationship() )#</td>
					<td>#encodeForHTML( row.getExEmail() )#</td>
					<td>#encodeForHTML( row.getExPhone() )#</td>
				</tr>
			</cfloop>
		</tbody>
	</table>
</cfif>

<h2>Guardian for children</h2>
<table>
	<tr><th>Name</th><td>#encodeForHTML( s.getGuardName() )#</td></tr>
	<tr><th>Address</th><td>#encodeForHTML( s.getGuardAddress() )#</td></tr>
	<tr><th>Children</th><td><pre style="margin:0;white-space:pre-wrap;font:inherit">#encodeForHTML( s.getGuardChildren() )#</pre></td></tr>
</table>

<cfif prc.related.backupGuardians.len()>
	<h2>Backup guardians</h2>
	<table>
		<thead><tr><th>Name</th><th>Address</th><th>Children</th></tr></thead>
		<tbody>
			<cfloop array="#prc.related.backupGuardians#" index="row">
				<tr>
					<td>#encodeForHTML( row.getGuardName() )#</td>
					<td>#encodeForHTML( row.getGuardAddress() )#</td>
					<td>#encodeForHTML( row.getGuardChildren() )#</td>
				</tr>
			</cfloop>
		</tbody>
	</table>
</cfif>

<cfif prc.related.gifts.len()>
	<h2>Specific gifts</h2>
	<table>
		<thead><tr><th>Item</th><th>Beneficiary</th></tr></thead>
		<tbody>
			<cfloop array="#prc.related.gifts#" index="row">
				<tr>
					<td>#encodeForHTML( row.getGiftItem() )#</td>
					<td>#encodeForHTML( row.getGiftBeneficiary() )#</td>
				</tr>
			</cfloop>
		</tbody>
	</table>
</cfif>

<h2>Residuary estate</h2>
<div style="background:##fff;border:1px solid var(--rule);border-radius:8px;padding:1rem">
	<pre style="margin:0;white-space:pre-wrap;font:inherit">#encodeForHTML( s.getEstateResidue() )#</pre>
</div>

<h2>Power of attorney</h2>
<table>
	<tr><th>Name</th><td>#encodeForHTML( s.getPoaName() )#</td></tr>
	<tr><th>Address</th><td>#encodeForHTML( s.getPoaAddress() )#</td></tr>
	<tr><th>Email</th><td>#encodeForHTML( s.getPoaEmail() )#</td></tr>
	<tr><th>Phone</th><td>#encodeForHTML( s.getPoaPhone() )#</td></tr>
	<tr><th>Authority begins</th><td>#encodeForHTML( s.getPoaCommence() )#</td></tr>
	<tr><th>Act jointly / severally</th><td>#encodeForHTML( s.getPoaActMode() )#</td></tr>
</table>

<cfif prc.related.additionalAttorneys.len()>
	<h2>Additional attorneys</h2>
	<table>
		<thead><tr><th>Name</th><th>Email</th><th>Phone</th><th>Begins</th></tr></thead>
		<tbody>
			<cfloop array="#prc.related.additionalAttorneys#" index="row">
				<tr>
					<td>#encodeForHTML( row.getPoaName() )#</td>
					<td>#encodeForHTML( row.getPoaEmail() )#</td>
					<td>#encodeForHTML( row.getPoaPhone() )#</td>
					<td>#encodeForHTML( row.getPoaCommence() )#</td>
				</tr>
			</cfloop>
		</tbody>
	</table>
</cfif>

<h2>Enduring guardian</h2>
<table>
	<tr><th>Name</th><td>#encodeForHTML( s.getEgName() )#</td></tr>
	<tr><th>Address</th><td>#encodeForHTML( s.getEgAddress() )#</td></tr>
	<tr><th>Email</th><td>#encodeForHTML( s.getEgEmail() )#</td></tr>
	<tr><th>Phone</th><td>#encodeForHTML( s.getEgPhone() )#</td></tr>
	<tr><th>Act jointly / severally</th><td>#encodeForHTML( s.getEgActMode() )#</td></tr>
	<tr><th>Directions</th><td><pre style="margin:0;white-space:pre-wrap;font:inherit">#encodeForHTML( s.getEgDirections() )#</pre></td></tr>
</table>

<cfif prc.related.backupEnduringGuardians.len()>
	<h2>Backup enduring guardians</h2>
	<table>
		<thead><tr><th>Name</th><th>Email</th><th>Phone</th></tr></thead>
		<tbody>
			<cfloop array="#prc.related.backupEnduringGuardians#" index="row">
				<tr>
					<td>#encodeForHTML( row.getEgName() )#</td>
					<td>#encodeForHTML( row.getEgEmail() )#</td>
					<td>#encodeForHTML( row.getEgPhone() )#</td>
				</tr>
			</cfloop>
		</tbody>
	</table>
</cfif>

<h2>Disposal of the body</h2>
<table>
	<tr><th>Wish</th><td>#encodeForHTML( s.getBodyDisposal() )#</td></tr>
	<tr><th>Instructions</th><td><pre style="margin:0;white-space:pre-wrap;font:inherit">#encodeForHTML( s.getBodyInstructions() )#</pre></td></tr>
</table>

<h2>Digital assets</h2>
<table>
	<tr><th>Include clauses</th><td>#encodeForHTML( s.getDaIncludeClauses() )#</td></tr>
	<tr><th>Instructions</th><td><pre style="margin:0;white-space:pre-wrap;font:inherit">#encodeForHTML( s.getDaInstructions() )#</pre></td></tr>
	<tr><th>Notes</th><td><pre style="margin:0;white-space:pre-wrap;font:inherit">#encodeForHTML( s.getDaNotes() )#</pre></td></tr>
</table>

<table>
	<tr><th>Status</th><td><span class="pill">#encodeForHTML( s.getStatus() )#</span></td></tr>
	<tr><th>Consent</th><td>#s.getConsentAccepted() ? "Accepted" : "Not recorded"#</td></tr>
	<tr><th>Sent from</th><td class="muted"><code>#encodeForHTML( s.getIpAddress() )#</code></td></tr>
</table>

<div class="actions-bar">
	<a class="btn secondary" href="/admin/will">Back</a>
	<cfif prc.canDelete>
		<form class="inline" method="post" action="/admin/will/remove/#s.getId()#"
		      onsubmit="return confirm('Delete this will submission permanently?')">
			<input type="hidden" name="csrfToken" value="#encodeForHTMLAttribute( prc.csrfToken )#">
			<button type="submit" class="danger">Delete</button>
		</form>
	</cfif>
</div>
</cfoutput>
