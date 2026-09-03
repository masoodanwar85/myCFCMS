<cfoutput>
<h1>Response</h1>
<p class="sub">
	<cfif !isNull( prc.form )>#encodeForHTML( prc.form.getName() )# &middot; </cfif>
	#dateTimeFormat( prc.submission.getCreatedAt(), "d mmm yyyy, HH:nn" )#
</p>

<!---
	Rendered from the response's own record of what was asked, not from the
	form's current fields. A form edited after this arrived must not change what
	this says happened — which is the whole reason answers carry their label.
--->
<table>
	<cfif len( prc.submission.getSenderEmail() ?: "" )>
		<tr>
			<th style="width:22%">Reply to</th>
			<td><a href="#xmlFormat( 'mailto:' & prc.submission.getSenderEmail() )#">#encodeForHTML( prc.submission.getSenderEmail() )#</a></td>
		</tr>
	</cfif>

	<cfif !prc.submission.getAnswers().len()>
		<tr><td colspan="2" class="muted">This response carried no answers.</td></tr>
	</cfif>

	<cfloop array="#prc.submission.getAnswers()#" index="answer">
		<cfset shown = prc.submission.displayValue( answer )>
		<tr>
			<th style="width:22%">#encodeForHTML( answer.label ?: answer.key ?: "" )#</th>
			<td>
				<cfif len( trim( shown ) )>
					<!--- Line breaks kept: a paragraph answer should read as it
					      was typed, and `white-space:pre-wrap` does that without
					      turning the value into markup. --->
					<pre style="margin:0;white-space:pre-wrap;font:inherit">#encodeForHTML( shown )#</pre>
				<cfelse>
					<span class="muted">(not answered)</span>
				</cfif>
			</td>
		</tr>
	</cfloop>
</table>

<h2>About this response</h2>
<table>
	<tr><th style="width:22%">Status</th><td><span class="pill #prc.submission.isNewMessage() ? 'on' : 'off'#">#encodeForHTML( prc.submission.getStatus() )#</span></td></tr>
	<tr><th>Sent from</th><td><code>#encodeForHTML( prc.submission.getIpAddress() ?: "" )#</code></td></tr>
	<tr><th>Browser</th><td class="muted" style="font-size:.85rem">#encodeForHTML( prc.submission.getUserAgent() ?: "" )#</td></tr>
</table>

<div class="actions-bar">
	<a class="btn secondary" href="/admin/forms">Back to responses</a>

	<cfloop array="#[ 'new', 'read', 'spam' ]#" index="state">
		<cfif prc.submission.getStatus() neq state>
			<form class="inline" method="post" action="/admin/forms/status/#prc.submission.getId()#">
				<input type="hidden" name="csrfToken" value="#encodeForHTMLAttribute( prc.csrfToken )#">
				<input type="hidden" name="to" value="#state#">
				<button type="submit" class="ico">Mark #state#</button>
			</form>
		</cfif>
	</cfloop>

	<cfif prc.canDelete>
		<form class="inline" method="post" action="/admin/forms/remove/#prc.submission.getId()#"
		      onsubmit="return confirm('Delete this response permanently?')">
			<input type="hidden" name="csrfToken" value="#encodeForHTMLAttribute( prc.csrfToken )#">
			<button type="submit" class="ico danger">Delete</button>
		</form>
	</cfif>
</div>
</cfoutput>
