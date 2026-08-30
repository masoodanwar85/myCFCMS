<cfoutput>
<article data-view="starter-will-form">
	<h1>Create your will</h1>

	<cfif args.errors.len()>
		<div role="alert" style="border-left:3px solid ##b91c1c;padding:.5rem 0 .5rem .75rem;margin:1rem 0">
			<cfloop array="#args.errors#" index="problem">
				<p style="margin:.15rem 0;color:##b91c1c">#encodeForHTML( problem )#</p>
			</cfloop>
		</div>
	</cfif>

	<form method="post" action="#xmlFormat( args.action )#">
		<input type="hidden" name="csrfToken" value="#xmlFormat( args.csrfToken )#">

		<div style="position:absolute;left:-9999px" aria-hidden="true">
			<label for="#xmlFormat( args.honeypotField )#">Leave this blank</label>
			<input type="text" id="#xmlFormat( args.honeypotField )#"
			       name="#xmlFormat( args.honeypotField )#" tabindex="-1" autocomplete="off">
		</div>

		<!--- Paste wizard fields here. Do not add another <form>. See themes/willcreator/views/will-form.cfm for the field-name list. --->

		<cfif len( args.recaptchaSiteKey ?: "" )>
			<div class="g-recaptcha" data-sitekey="#xmlFormat( args.recaptchaSiteKey )#" style="margin:1.25rem 0"></div>
			<script src="https://www.google.com/recaptcha/api.js" async defer></script>
		</cfif>
		<p><button type="submit">Submit will</button></p>
	</form>
</article>
</cfoutput>
