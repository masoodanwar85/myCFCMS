<cfoutput>
<!---
	A response to an author-defined form, as an email.

	Every answer is rendered from the submission's own record of what was asked
	— label beside value — rather than from the form's live fields. A form
	edited between the response arriving and the email being read must not
	change what the email says happened.
--->
<h2 style="margin:0 0 1rem;font:600 1.05rem/1.3 system-ui,sans-serif;color:##1f2937">
	#encodeForHTML( args.formName )#
</h2>

<cfif !args.answers.len()>
	<p style="color:##6b7280">This response contained no answers.</p>
<cfelse>
	<table role="presentation" cellpadding="0" cellspacing="0" style="width:100%;border-collapse:collapse">
		<cfloop array="#args.answers#" index="answer">
			<cfset value = isArray( answer.value ?: "" ) ? arrayToList( answer.value, ", " ) : toString( answer.value ?: "" )>
			<tr>
				<th align="left" valign="top"
				    style="padding:.5rem .75rem .5rem 0;border-bottom:1px solid ##e5e7eb;font:600 .85rem/1.4 system-ui,sans-serif;color:##374151;white-space:nowrap">
					#encodeForHTML( answer.label ?: answer.key ?: "" )#
				</th>
				<td valign="top"
				    style="padding:.5rem 0;border-bottom:1px solid ##e5e7eb;font:.9rem/1.5 system-ui,sans-serif;color:##1f2937">
					<cfif len( trim( value ) )>
						<!--- Line breaks preserved: a paragraph answer typed
						      across several lines should read as it was typed. --->
						#replace( encodeForHTML( value ), chr( 10 ), "<br>", "all" )#
					<cfelse>
						<span style="color:##9ca3af">(not answered)</span>
					</cfif>
				</td>
			</tr>
		</cfloop>
	</table>
</cfif>
</cfoutput>
