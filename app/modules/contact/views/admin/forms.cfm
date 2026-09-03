<cfoutput>
<h1>Contact form</h1>
<p class="sub">
	This site's enquiry form. It is served at <code>/contact</code> and can also be placed in any
	page or post with <code>[contact-form]</code>.
</p>

<cfif isNull( prc.form )>
	<!---
		A site provisioned without one, or with its only form deactivated.
		`/contact` falls through to Pages in that state, so an ordinary page at
		that path still works — this screen is how you get the form back.
	--->
	<p class="muted">This site has no contact form yet.</p>

	<h2>Create the contact form</h2>
	<form class="narrow" method="post" action="/admin/contact/createForm">
		<input type="hidden" name="csrfToken" value="#encodeForHTMLAttribute( prc.csrfToken )#">
		<label for="newName">Name</label>
		<input type="text" id="newName" name="name" placeholder="Contact Us" required>

		<label for="newRcpt">Send enquiries to</label>
		<input type="email" id="newRcpt" name="recipientEmail" placeholder="enquiries@example.com">

		<div class="actions-bar"><button type="submit">Create form</button></div>
	</form>
<cfelse>
	<cfset f = prc.form>
	<form method="post" action="/admin/contact/updateForm/#f.getId()#">
		<input type="hidden" name="csrfToken" value="#encodeForHTMLAttribute( prc.csrfToken )#">

		<div class="grid2">
			<div>
				<label for="name">Name</label>
				<input type="text" id="name" name="name" value="#encodeForHTMLAttribute( f.getName() )#">
			</div>
			<div>
				<label for="rcpt">Send enquiries to</label>
				<input type="email" id="rcpt" name="recipientEmail"
				       value="#encodeForHTMLAttribute( f.getRecipientEmail() ?: '' )#">
			</div>
		</div>

		<label for="intro">Intro shown above the form</label>
		<input type="text" id="intro" name="intro" value="#encodeForHTMLAttribute( f.getIntro() ?: '' )#">

		<label for="msg">Message shown after sending</label>
		<input type="text" id="msg" name="successMessage" value="#encodeForHTMLAttribute( f.getSuccessMessage() )#">

		<label for="typ">Thank-you page <span class="muted" style="font-weight:400">optional</span></label>
		<input type="text" id="typ" name="thankYouPath" placeholder="leave blank to stay on the page"
		       value="#encodeForHTMLAttribute( f.getThankYouPath() ?: '' )#">
		<p class="muted" style="font-size:.8rem">
			Blank is usually right: the message above replaces the form where it stands. Set a path
			such as <code>/thank-you</code> when you need the visitor to land on a real page &mdash;
			advertising conversion tracking fires on a page being loaded, and a message swapped in
			by the server never produces one. Site paths only, starting with <code>/</code>.
		</p>

		<label style="display:flex;gap:.4rem;align-items:center;color:var(--ink)">
			<input type="checkbox" name="isActive" value="yes" style="width:auto" #f.getIsActive() ? 'checked' : ''#>
			Accepting messages
		</label>

		<div class="actions-bar"><button type="submit">Save form</button></div>
	</form>
</cfif>

<cfif prc.extras.len()>
	<hr style="margin:2.5rem 0;border:0;border-top:1px solid var(--rule)">

	<h2>Other forms</h2>
	<p class="muted" style="font-size:.85rem">
		A site has one contact form. These are left over from when it could have several &mdash; they
		are not served anywhere and are kept only so nothing is lost. A form that needs its own
		fields belongs in <strong>Forms</strong>; delete these once you have moved them.
	</p>

	<table>
		<thead><tr><th>Name</th><th>Sends to</th><th class="c">Enquiries</th><th class="r"></th></tr></thead>
		<tbody>
			<cfloop array="#prc.extras#" index="x">
				<tr>
					<td>#encodeForHTML( x.getName() )# <span class="muted">/#encodeForHTML( x.getSlug() )#</span></td>
					<td>#encodeForHTML( x.getRecipientEmail() ?: "" )#</td>
					<td class="c">#prc.extraCounts[ x.getId() ] ?: 0#</td>
					<td class="actions">
						<form class="inline" method="post" action="/admin/contact/deleteForm/#x.getId()#"
						      onsubmit="return confirm('Delete #encodeForJavaScript( x.getName() )# AND every enquiry sent through it?')">
							<input type="hidden" name="csrfToken" value="#encodeForHTMLAttribute( prc.csrfToken )#">
							<button type="submit" class="ico danger">Delete</button>
						</form>
					</td>
				</tr>
			</cfloop>
		</tbody>
	</table>
</cfif>
</cfoutput>
