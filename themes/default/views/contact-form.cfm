<cfoutput>
<!---
	`args.embedded` is true when this comes from the `[contact-form]` shortcode
	rather than from `/contact`. The page around it already has a heading and a
	wrapper, so both are dropped — a second `<h1>` would give the page two
	competing titles, which is the same trap `show_heading` exists to avoid.
--->
<cfif !( args.embedded ?: false )><article data-view="default-contact-form"></cfif>
	<cfif !( args.embedded ?: false )><h1>#encodeForHTML( args.form.getName() )#</h1></cfif>

	<cfif len( args.form.getIntro() ?: "" )>
		<p>#encodeForHTML( args.form.getIntro() )#</p>
	</cfif>

	<cfif args.errors.len()>
		<div role="alert" style="border-left:3px solid ##b91c1c;padding:.5rem 0 .5rem .75rem;margin:1rem 0">
			<cfloop array="#args.errors#" index="problem">
				<p style="margin:.15rem 0;color:##b91c1c">#encodeForHTML( problem )#</p>
			</cfloop>
		</div>
	</cfif>

	<form method="post" action="#xmlFormat( args.action )#">
		<input type="hidden" name="csrfToken" value="#xmlFormat( args.csrfToken )#">
		<input type="hidden" name="form" value="#encodeForHTMLAttribute( args.form.getSlug() )#">

		<!--- Left empty by a person; filled in by a bot. Hidden from both
		      sighted users and screen readers. --->
		<div style="position:absolute;left:-9999px" aria-hidden="true">
			<label for="#xmlFormat( args.honeypotField )#">Leave this blank</label>
			<input type="text" id="#xmlFormat( args.honeypotField )#"
			       name="#xmlFormat( args.honeypotField )#" tabindex="-1" autocomplete="off">
		</div>

		<p>
			<label for="name">Your name</label><br>
			<input type="text" id="name" name="name" required maxlength="150" style="width:100%;max-width:24rem"
			       value="#xmlFormat( args.values.name ?: '' )#">
		</p>
		<p>
			<label for="email">Your email</label><br>
			<input type="email" id="email" name="email" required maxlength="191" style="width:100%;max-width:24rem"
			       value="#xmlFormat( args.values.email ?: '' )#">
		</p>
		<p>
			<label for="subject">Subject</label><br>
			<input type="text" id="subject" name="subject" maxlength="255" style="width:100%;max-width:24rem"
			       value="#xmlFormat( args.values.subject ?: '' )#">
		</p>
		<p>
			<label for="message">Message</label><br>
			<textarea id="message" name="message" required rows="8" maxlength="10000"
			          style="width:100%;max-width:32rem">#encodeForHTML( args.values.message ?: '' )#</textarea>
		</p>

		<cfif len( args.recaptchaSiteKey ?: "" )>
			<!---
				Rendered only when the site has *both* keys. The `data-sitekey`
				is public by design — the widget cannot work otherwise — and the
				secret never appears here or anywhere else the browser can see.

				`async defer` so a slow or blocked Google does not hold up the
				rest of the page; the form still renders and the server still
				refuses an unverified submission either way.
			--->
			<div class="g-recaptcha" data-sitekey="#xmlFormat( args.recaptchaSiteKey )#" style="margin:1.25rem 0"></div>
			<script src="https://www.google.com/recaptcha/api.js" async defer></script>
		</cfif>
		<p><button type="submit">Send message</button></p>
	</form>
<cfif !( args.embedded ?: false )></article></cfif>
</cfoutput>
