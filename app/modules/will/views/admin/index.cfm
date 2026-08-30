<cfoutput>
<h1>Wills</h1>
<p class="sub">
	Questionnaire submissions for #encodeForHTML( prc.currentSite.getName() )#.
	The public form is at <code>/will</code>.
</p>

<div class="adm-toolbar">
	<span class="adm-count">#prc.pagination.total# submissions</span>
</div>

<table>
	<thead>
		<tr>
			<th style="width:28%">Will maker</th>
			<th>Executor</th>
			<th>Received</th>
			<th class="c">Status</th>
			<th class="r">Actions</th>
		</tr>
	</thead>
	<tbody>
		<cfif !prc.submissions.len()>
			<tr><td colspan="5" class="muted">Nothing here.</td></tr>
		</cfif>
		<cfloop array="#prc.submissions#" index="s">
			<tr>
				<td>
					<strong>#encodeForHTML( s.getWmFullname() )#</strong>
					<div class="muted" style="font-size:.8rem">#encodeForHTML( s.getWmEmail() )#</div>
				</td>
				<td>#encodeForHTML( s.getExName() )#</td>
				<td class="muted">#dateTimeFormat( s.getCreatedAt(), "d mmm yyyy, HH:nn" )#</td>
				<td class="c"><span class="pill on">#encodeForHTML( s.getStatus() )#</span></td>
				<td class="r nowrap">
					<a class="ico" href="/admin/will/view/#s.getId()#" title="Read this submission">Read</a>
					<cfif prc.canDelete>
						<form class="inline" method="post" action="/admin/will/remove/#s.getId()#"
						      onsubmit="return confirm('Delete this will submission permanently?')">
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
