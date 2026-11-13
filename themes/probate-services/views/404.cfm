<cfoutput>
<section class="section">
	<div class="wrap stack">
		<span class="eyebrow">Page not found</span>
		<h1>That page is not here</h1>
		<p class="lead">
			There is nothing at <code>/#encodeForHTML( args.path )#</code> on this site.
			It may have been moved, or the address may have a typo in it.
		</p>
		<div class="btn-row">
			<a class="btn" href="/">Back to the home page</a>
			<a class="btn btn--line" href="/contact">Contact us</a>
		</div>
	</div>
</section>
</cfoutput>
