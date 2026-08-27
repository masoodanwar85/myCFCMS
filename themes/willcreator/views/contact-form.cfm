<cfoutput>
<article class="section">
	<h1>#encodeForHTML( args.form.getName() )#</h1>

	<cfif len( args.form.getIntro() ?: "" )>
		<p>#encodeForHTML( args.form.getIntro() )#</p>
	</cfif>

	<cfif args.errors.len()>
		<div class="flash error" role="alert">
			<cfloop array="#args.errors#" index="problem">
				<p style="margin:.15rem 0">#encodeForHTML( problem )#</p>
			</cfloop>
		</div>
	</cfif>

	<form method="post" action="#xmlFormat( args.action )#">
		<input type="hidden" name="csrfToken" value="#xmlFormat( args.csrfToken )#">
		<input type="hidden" name="form" value="#encodeForHTMLAttribute( args.form.getSlug() )#">

		<!--- Left empty by a person; filled in by a bot. The field name comes
		      from the module rather than being hardcoded here, so a theme
		      cannot quietly break the trap by renaming it. --->
		<div style="position:absolute;left:-9999px" aria-hidden="true">
			<label for="#xmlFormat( args.honeypotField )#">Leave this blank</label>
			<input type="text" id="#xmlFormat( args.honeypotField )#"
			       name="#xmlFormat( args.honeypotField )#" tabindex="-1" autocomplete="off">
		</div>

		<label for="name">Your name</label>
		<input type="text" id="name" name="name" required maxlength="150"
		       value="#xmlFormat( args.values.name ?: '' )#">

		<label for="email">Your email</label>
		<input type="email" id="email" name="email" required maxlength="191"
		       value="#xmlFormat( args.values.email ?: '' )#">

		<label for="subject">Subject</label>
		<input type="text" id="subject" name="subject" maxlength="255"
		       value="#xmlFormat( args.values.subject ?: '' )#">

		<label for="message">Message</label>
		<textarea id="message" name="message" required rows="8" maxlength="10000">#encodeForHTML( args.values.message ?: '' )#</textarea>


		<cfif len( args.recaptchaSiteKey ?: "" )>
			<!---
				Rendered only when the site has *both* keys. The `data-sitekey`
				is public by design — the widget cannot work otherwise — and the
				secret never appears here or anywhere else the browser can see.

				`async defer` so a slow or blocked Google does not hold up the
				rest of the page; the form still renders and the server still
				refuses an unverified submission either way.
			--->
			<!--- Wrapped in `.g-recaptcha-container`, which this theme already styles. --->
			<div class="g-recaptcha-container">
				<div class="g-recaptcha" data-sitekey="#xmlFormat( args.recaptchaSiteKey )#"></div>
			</div>
			<script src="https://www.google.com/recaptcha/api.js" async defer></script>
		</cfif>
		<p style="margin-top:1.5rem"><button type="submit">Send message</button></p>
	</form>
</article>
</cfoutput>
