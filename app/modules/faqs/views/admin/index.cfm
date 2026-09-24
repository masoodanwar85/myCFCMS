<cfoutput>
<h1>FAQs</h1>
<p class="sub">Questions and answers for #encodeForHTML( prc.currentSite.getName() )#.</p>

<div class="adm-toolbar">
	<cfif prc.canManage><a class="btn" href="/admin/faqs/new">+ New FAQ</a></cfif>
	<a class="btn secondary" href="/faq" target="_blank" rel="noopener">View FAQs &nearr;</a>
	<span class="adm-count">#prc.faqs.len()# FAQs</span>
</div>

<table>
	<thead>
		<tr>
			<th style="width:8%">Order</th>
			<th>Question</th>
			<th class="c">Status</th>
			<th class="r">Actions</th>
		</tr>
	</thead>
	<tbody>
		<cfif !prc.faqs.len()>
			<tr><td colspan="4" class="muted">No FAQs yet.</td></tr>
		</cfif>
		<cfloop array="#prc.faqs#" index="faq">
			<tr class="#faq.getIsPublished() ? '' : 'is-off'#">
				<td class="muted">#encodeForHTML( faq.getSortOrder() )#</td>
				<td>
					<cfif prc.canManage>
						<a href="/admin/faqs/edit/#faq.getId()#"><strong>#encodeForHTML( faq.getQuestion() )#</strong></a>
					<cfelse>
						<strong>#encodeForHTML( faq.getQuestion() )#</strong>
					</cfif>
				</td>
				<td class="c">
					<cfif prc.canManage>
						<form class="inline" method="post" action="/admin/faqs/#faq.getIsPublished() ? 'unpublish' : 'publish'#/#faq.getId()#">
							<input type="hidden" name="csrfToken" value="#encodeForHTMLAttribute( prc.csrfToken )#">
							<button type="submit" class="pill #faq.getIsPublished() ? 'on' : 'off'#"
							        title="#faq.getIsPublished() ? 'Unpublish' : 'Publish'#">#faq.getIsPublished() ? "Published" : "Draft"#</button>
						</form>
					<cfelse>
						<span class="pill #faq.getIsPublished() ? 'on' : 'off'#">#faq.getIsPublished() ? "Published" : "Draft"#</span>
					</cfif>
				</td>
				<td class="r nowrap">
					<cfif prc.canManage>
						<a class="ico" href="/admin/faqs/edit/#faq.getId()#" title="Edit">Edit</a>
						<form class="inline" method="post" action="/admin/faqs/remove/#faq.getId()#"
						      onsubmit="return confirm('Delete #encodeForJavaScript( faq.getQuestion() )#?')">
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
