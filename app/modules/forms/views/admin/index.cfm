<cfoutput>
<h1>Form responses</h1>
<p class="sub">
	What people sent through this site's forms.
	<cfif prc.canManage>
		<a href="/admin/forms/forms">Build forms &rarr;</a>
	</cfif>
</p>

<!---
	Two filters, and they compose: a status and a form. Kept as query
	parameters rather than as session state so a filtered inbox is a URL
	somebody can bookmark or send to a colleague.
--->
<div class="adm-toolbar">
	<cfset base = "/admin/forms?">
	<cfset formPart = prc.formId ? "&formId=" & prc.formId : "">

	<a class="btn #len( prc.filter ) ? 'secondary' : ''#" href="#base##formPart#">All</a>
	<cfloop array="#[ 'new', 'read', 'spam' ]#" index="state">
		<a class="btn #prc.filter eq state ? '' : 'secondary'#"
		   href="#base#status=#state##formPart#">#state#</a>
	</cfloop>

	<cfif prc.forms.len()>
		<form method="get" action="/admin/forms" class="inline" style="margin-left:auto">
			<cfif len( prc.filter )><input type="hidden" name="status" value="#encodeForHTMLAttribute( prc.filter )#"></cfif>
			<select name="formId" onchange="this.form.submit()">
				<option value="0">Every form</option>
				<cfloop array="#prc.forms#" index="f">
					<option value="#f.getId()#" <cfif prc.formId eq f.getId()>selected</cfif>>#encodeForHTML( f.getName() )#</option>
				</cfloop>
			</select>
			<noscript><button type="submit" class="ico">Filter</button></noscript>
		</form>
	</cfif>

	<span class="adm-count">#prc.pagination.total# response<cfif prc.pagination.total neq 1>s</cfif></span>
</div>

<table>
	<thead>
		<tr>
			<th style="width:22%">From</th>
			<th>Response</th>
			<th style="width:16%">Form</th>
			<th style="width:14%">Received</th>
			<th class="c">Status</th>
			<th class="r">Actions</th>
		</tr>
	</thead>
	<tbody>
		<cfif !prc.submissions.len()>
			<tr><td colspan="6" class="muted">Nothing here.</td></tr>
		</cfif>

		<cfloop array="#prc.submissions#" index="s">
			<cfset formName = "">
			<cfloop array="#prc.forms#" index="f">
				<cfif f.getId() eq s.getFormId()><cfset formName = f.getName()></cfif>
			</cfloop>

			<tr>
				<td>
					<cfif len( s.getSenderEmail() ?: "" )>
						<a href="#xmlFormat( 'mailto:' & s.getSenderEmail() )#">#encodeForHTML( s.getSenderEmail() )#</a>
					<cfelse>
						<!--- Not every form asks for an address. Saying so beats
						      an empty cell that looks like a bug. --->
						<span class="muted">no address given</span>
					</cfif>
				</td>
				<td>
					<a href="/admin/forms/view/#s.getId()#">
						<cfif len( s.getSummary() ?: "" )>
							#encodeForHTML( s.getSummary() )#
						<cfelse>
							<span class="muted">(no answers)</span>
						</cfif>
					</a>
				</td>
				<td class="muted">#encodeForHTML( formName )#</td>
				<td class="muted">#dateTimeFormat( s.getCreatedAt(), "d mmm yyyy, HH:nn" )#</td>
				<td class="c"><span class="pill #s.isNewMessage() ? 'on' : 'off'#">#encodeForHTML( s.getStatus() )#</span></td>
				<td class="actions">
					<a class="ico" href="/admin/forms/view/#s.getId()#">Open</a>
					<cfif s.getStatus() neq "spam">
						<form class="inline" method="post" action="/admin/forms/status/#s.getId()#">
							<input type="hidden" name="csrfToken" value="#encodeForHTMLAttribute( prc.csrfToken )#">
							<input type="hidden" name="to" value="spam">
							<button type="submit" class="ico">Spam</button>
						</form>
					</cfif>
					<cfif prc.canDelete>
						<form class="inline" method="post" action="/admin/forms/remove/#s.getId()#"
						      onsubmit="return confirm('Delete this response permanently?')">
							<input type="hidden" name="csrfToken" value="#encodeForHTMLAttribute( prc.csrfToken )#">
							<button type="submit" class="ico danger">Delete</button>
						</form>
					</cfif>
				</td>
			</tr>
		</cfloop>
	</tbody>
</table>

<cfinclude template="/core/views/_pagination.cfm">
</cfoutput>
