<cfoutput>
<h2 style="font-size:1.1rem;margin:0 0 1rem">New enquiry via #encodeForHTML( args.formName )#</h2>

<table cellpadding="0" cellspacing="0" style="font-size:.95rem;margin-bottom:1rem">
	<tr>
		<td style="padding:.15rem 1rem .15rem 0;color:##6b7280">From</td>
		<td style="padding:.15rem 0">#encodeForHTML( args.name )#</td>
	</tr>
	<tr>
		<td style="padding:.15rem 1rem .15rem 0;color:##6b7280">Email</td>
		<td style="padding:.15rem 0">#encodeForHTML( args.email )#</td>
	</tr>
	<cfif len( args.subject ?: "" )>
		<tr>
			<td style="padding:.15rem 1rem .15rem 0;color:##6b7280">Subject</td>
			<td style="padding:.15rem 0">#encodeForHTML( args.subject )#</td>
		</tr>
	</cfif>
</table>

<!--- Escaped and preformatted: this came from an anonymous visitor. --->
<div style="background:##f7f7f8;border:1px solid ##e5e7eb;border-radius:8px;padding:1rem">
	<pre style="margin:0;white-space:pre-wrap;font:inherit">#encodeForHTML( args.message )#</pre>
</div>

<p style="font-size:.85rem;color:##6b7280;margin-top:1rem">
	Reply directly to this email to answer #encodeForHTML( args.name )#.
</p>
</cfoutput>
