<cfoutput>
<!---
	Shown in place of the form after a response is accepted, when the form has
	no thank-you page of its own.

	No heading: this replaces a form inside a page that already has one, and a
	second `<h1>` would give the page two competing titles.
--->
<div class="cms-form cms-form--sent" data-form="#xmlFormat( args.form.getSlug() )#">
	<p class="cms-form__sent" role="status">#encodeForHTML( args.message )#</p>
</div>
</cfoutput>
