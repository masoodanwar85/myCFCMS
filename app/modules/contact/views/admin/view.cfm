<cfoutput>
<h1>Enquiry</h1>
<p class="sub">Received #dateTimeFormat( prc.submission.getCreatedAt(), "d mmmm yyyy, HH:nn" )#</p>

<table>
	<tr><th>From</th><td>#encodeForHTML( prc.submission.getName() )#</td></tr>
	<tr>
		<th>Email</th>
		<td><a href="#xmlFormat( 'mailto:' & prc.submission.getEmail() )#">#encodeForHTML( prc.submission.getEmail() )#</a></td>
	</tr>
	<tr><th>Subject</th><td>#encodeForHTML( len( prc.submission.getSubject() ) ? prc.submission.getSubject() : "(none)" )#</td></tr>
	<tr><th>Status</th><td><span class="pill">#encodeForHTML( prc.submission.getStatus() )#</span></td></tr>
	<tr><th>Sent from</th><td class="muted"><code>#encodeForHTML( prc.submission.getIpAddress() )#</code></td></tr>
</table>

<h2>Message</h2>
<!--- Escaped, and rendered as preformatted text. This came from an anonymous
      visitor and is never treated as markup. --->
<div style="background:##fff;border:1px solid var(--rule);border-radius:8px;padding:1rem">
	<pre style="margin:0;white-space:pre-wrap;font:inherit">#encodeForHTML( prc.submission.getMessage() )#</pre>
</div>

<div class="actions-bar">
	<a class="btn secondary" href="/admin/contact">Back</a>
	<form class="inline" method="post" action="/admin/contact/status/#prc.submission.getId()#">
		<input type="hidden" name="csrfToken" value="#encodeForHTMLAttribute( prc.csrfToken )#">
		<input type="hidden" name="to" value="#prc.submission.isSpam() ? 'read' : 'spam'#">
		<button type="submit" class="secondary">#prc.submission.isSpam() ? "Not spam" : "Mark as spam"#</button>
	</form>
	<cfif prc.canDelete>
		<form class="inline" method="post" action="/admin/contact/remove/#prc.submission.getId()#"
		      onsubmit="return confirm('Delete this enquiry permanently?')">
			<input type="hidden" name="csrfToken" value="#encodeForHTMLAttribute( prc.csrfToken )#">
			<button type="submit" class="danger">Delete</button>
		</form>
	</cfif>
</div>
</cfoutput>
