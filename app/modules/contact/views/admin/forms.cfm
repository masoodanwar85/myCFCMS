<cfoutput>
<h1>Contact forms</h1>
<p class="sub">The form served at <code>/contact</code> is this site's first active one.</p>

<cfloop array="#prc.forms#" index="f">
	<form method="post" action="/admin/contact/updateForm/#f.getId()#" style="margin-bottom:2rem">
		<input type="hidden" name="csrfToken" value="#encodeForHTMLAttribute( prc.csrfToken )#">
		<h2>#encodeForHTML( f.getName() )# <span class="muted" style="font-weight:400">/#encodeForHTML( f.getSlug() )#</span></h2>

		<div class="grid2">
			<div>
				<label for="name#f.getId()#">Name</label>
				<input type="text" id="name#f.getId()#" name="name" value="#encodeForHTMLAttribute( f.getName() )#">
			</div>
			<div>
				<label for="rcpt#f.getId()#">Send enquiries to</label>
				<input type="email" id="rcpt#f.getId()#" name="recipientEmail"
				       value="#encodeForHTMLAttribute( f.getRecipientEmail() ?: '' )#">
			</div>
		</div>

		<label for="intro#f.getId()#">Intro shown above the form</label>
		<input type="text" id="intro#f.getId()#" name="intro" value="#encodeForHTMLAttribute( f.getIntro() ?: '' )#">

		<label for="msg#f.getId()#">Message shown after sending</label>
		<input type="text" id="msg#f.getId()#" name="successMessage" value="#encodeForHTMLAttribute( f.getSuccessMessage() )#">

		<label style="display:flex;gap:.4rem;align-items:center;color:var(--ink)">
			<input type="checkbox" name="isActive" value="yes" style="width:auto" #f.getIsActive() ? 'checked' : ''#>
			Accepting messages
		</label>

		<div class="actions-bar">
			<button type="submit">Save form</button>
		</div>
	</form>

	<form method="post" action="/admin/contact/deleteForm/#f.getId()#"
	      onsubmit="return confirm('Delete this form AND every enquiry sent through it?')">
		<input type="hidden" name="csrfToken" value="#encodeForHTMLAttribute( prc.csrfToken )#">
		<button type="submit" class="danger">Delete form and its enquiries</button>
	</form>
	<hr style="margin:2rem 0;border:0;border-top:1px solid var(--rule)">
</cfloop>

<h2>Add a form</h2>
<form method="post" action="/admin/contact/createForm">
	<input type="hidden" name="csrfToken" value="#encodeForHTMLAttribute( prc.csrfToken )#">
	<div class="grid2">
		<div>
			<label for="newName">Name</label>
			<input type="text" id="newName" name="name" placeholder="Contact us" required>
		</div>
		<div>
			<label for="newRcpt">Send enquiries to</label>
			<input type="email" id="newRcpt" name="recipientEmail" placeholder="hello@example.com">
		</div>
	</div>
	<div class="actions-bar"><button type="submit">Create form</button></div>
</form>

<div class="actions-bar"><a class="btn secondary" href="/admin/contact">Back to enquiries</a></div>
</cfoutput>
