<cfoutput>
<h1>Forms</h1>
<p class="sub">
	Forms with fields you define. Place one in a page or post with
	<code>[form slug="&hellip;"]</code>. The site's enquiry form is separate &mdash; it lives under
	<a href="/admin/contact/forms">Contact</a>.
</p>

<cfif !prc.forms.len()>
	<p class="muted">No forms yet.</p>
<cfelse>
	<table>
		<thead>
			<tr>
				<th style="width:35%">Form</th>
				<th>Shortcode</th>
				<th class="c">Responses</th>
				<th class="c">Status</th>
				<th class="r">Actions</th>
			</tr>
		</thead>
		<tbody>
			<cfloop array="#prc.forms#" index="f">
				<tr>
					<td>
						<a href="/admin/forms/build/#f.getId()#"><strong>#encodeForHTML( f.getName() )#</strong></a>
						<cfif len( f.getRecipientEmail() ?: "" )>
							<div class="muted" style="font-size:.8rem">#encodeForHTML( f.getRecipientEmail() )#</div>
						</cfif>
					</td>
					<td><code>[form slug="#encodeForHTML( f.getSlug() )#"]</code></td>
					<td class="c">
						<cfif prc.counts[ f.getId() ] ?: 0>
							<a href="/admin/forms?formId=#f.getId()#">#prc.counts[ f.getId() ]#</a>
						<cfelse>
							<span class="muted">0</span>
						</cfif>
					</td>
					<td class="c">
						<span class="pill #f.getIsActive() ? 'on' : 'off'#">#f.getIsActive() ? "active" : "off"#</span>
					</td>
					<td class="actions">
						<a class="ico" href="/admin/forms/build/#f.getId()#">Build</a>
						<form class="inline" method="post" action="/admin/forms/destroy/#f.getId()#"
						      onsubmit="return confirm('Delete #encodeForJavaScript( f.getName() )# and its #prc.counts[ f.getId() ] ?: 0# response(s)?')">
							<input type="hidden" name="csrfToken" value="#encodeForHTMLAttribute( prc.csrfToken )#">
							<button type="submit" class="ico danger">Delete</button>
						</form>
					</td>
				</tr>
			</cfloop>
		</tbody>
	</table>
</cfif>

<h2>Add a form</h2>
<form class="narrow" method="post" action="/admin/forms/create">
	<input type="hidden" name="csrfToken" value="#encodeForHTMLAttribute( prc.csrfToken )#">

	<label for="name">Name</label>
	<input type="text" id="name" name="name" placeholder="Registration" required>

	<label for="slug">Shortcode name <span class="muted" style="font-weight:400">optional</span></label>
	<input type="text" id="slug" name="slug" placeholder="derived from the name">
	<p class="muted" style="font-size:.8rem">
		What goes in <code>[form slug="&hellip;"]</code>. Changing it later means editing every page
		the form appears on, so it is set once here.
	</p>

	<label for="recipientEmail">Send responses to <span class="muted" style="font-weight:400">optional</span></label>
	<input type="email" id="recipientEmail" name="recipientEmail" placeholder="bookings@example.com">

	<div class="actions-bar"><button type="submit">Create form</button></div>
</form>
</cfoutput>
