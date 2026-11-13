<cfoutput>
<!---
	`args.embedded` is true when this follows the `[contact-form]` shortcode
	rather than `/contact`. The page around it already has a heading and a
	wrapper, so both are dropped — a second <h1> would give the page two
	competing titles.
--->
<cfif !( args.embedded ?: false )>
<section class="section">
	<div class="wrap stack">
		<span class="eyebrow">Thank you</span>
		<h1>Your message is with us</h1>
</cfif>
		<p class="lead">#encodeForHTML( args.message )#</p>
<cfif !( args.embedded ?: false )>
		<div class="btn-row"><a class="btn" href="/">Back to the home page</a></div>
	</div>
</section>
</cfif>
</cfoutput>
