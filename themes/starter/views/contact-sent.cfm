<cfoutput>
<cfif !( args.embedded ?: false )><article data-view="starter-contact-sent"></cfif>
	<cfif !( args.embedded ?: false )><h1>Thank you</h1></cfif>
	<p>#encodeForHTML( args.message )#</p>
	<cfif !( args.embedded ?: false )><p><a href="/">Back to the home page</a></p></cfif>
<cfif !( args.embedded ?: false )></article></cfif>
</cfoutput>
