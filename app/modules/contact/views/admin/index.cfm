<cfoutput>
<h1>Enquiries</h1>
<p class="sub">
	Messages sent through #encodeForHTML( prc.currentSite.getName() )#.
	<cfif prc.newCount><strong>#prc.newCount# new</strong>.</cfif>
</p>

<cfset local.filter = rc.status ?: "">
<div class="adm-toolbar">
	<a class="btn secondary#local.filter eq '' ? ' is-current' : ''#" href="/admin/contact">All</a>
	<a class="btn secondary#local.filter eq 'new' ? ' is-current' : ''#" href="/admin/contact?status=new">New</a>
	<a class="btn secondary#local.filter eq 'read' ? ' is-current' : ''#" href="/admin/contact?status=read">Read</a>
	<a class="btn secondary#local.filter eq 'spam' ? ' is-current' : ''#" href="/admin/contact?status=spam">Spam</a>
	<span class="adm-count">#prc.pagination.total# enquiries</span>
	<!--- Not a filter: a link to the form definitions, so it sits past the count. --->
	<cfif prc.canManage><a class="btn secondary" href="/admin/contact/forms">Forms &rarr;</a></cfif>
</div>

<cfif !prc.forms.len()>
	<p class="flash error">This site has no contact form yet, so <code>/contact</code> is not served.
	<cfif prc.canManage><a href="/admin/contact/forms">Create one</a>.</cfif></p>
</cfif>

<table>
	<thead><tr><th style="width:24%">From</th><th>Subject</th><th>Received</th><th class="c">Status</th><th class="r">Actions</th></tr></thead>
	<tbody>
		<cfif !prc.submissions.len()>
			<tr><td colspan="5" class="muted">Nothing here.</td></tr>
		</cfif>
		<cfloop array="#prc.submissions#" index="s">
			<tr class="#s.isSpam() ? 'is-off' : ''#">
				<td>
					<strong>#encodeForHTML( s.getName() )#</strong>
					<div class="muted" style="font-size:.8rem">#encodeForHTML( s.getEmail() )#</div>
				</td>
				<td>
					#encodeForHTML( len( s.getSubject() ) ? s.getSubject() : "(no subject)" )#
					<div class="muted" style="font-size:.8rem">#encodeForHTML( s.getSummary() )#</div>
				</td>
				<td class="muted">#dateTimeFormat( s.getCreatedAt(), "d mmm yyyy, HH:nn" )#</td>
				<td class="c"><span class="pill #s.isNew() ? 'on' : 'off'#">#encodeForHTML( s.getStatus() )#</span></td>
				<td class="r nowrap">
					<a class="ico" href="/admin/contact/view/#s.getId()#" title="Read this enquiry">Read</a>
					<cfif !s.isSpam()>
						<form class="inline" method="post" action="/admin/contact/status/#s.getId()#">
							<input type="hidden" name="csrfToken" value="#encodeForHTMLAttribute( prc.csrfToken )#">
							<input type="hidden" name="to" value="spam">
							<button type="submit" class="ico" title="Mark as spam">Spam</button>
						</form>
					</cfif>
					<cfif prc.canDelete>
						<form class="inline" method="post" action="/admin/contact/remove/#s.getId()#"
						      onsubmit="return confirm('Delete this enquiry permanently?')">
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
