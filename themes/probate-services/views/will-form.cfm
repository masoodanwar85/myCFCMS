<cfoutput>
<!---
	The will questionnaire's shell.

	Deliberately a shell. This theme arrived as a copy of `willcreator`, whose
	version of this view is a 1,400-line wizard written for that firm's own
	questions — carrying it here would ship another client's form, styled for
	another client's stylesheet, on a site that has not asked for it.

	What it must do is satisfy the contract: the wills resolver names this view
	by name, and a theme that does not supply it answers a 500 rather than a
	page. So it renders the form, the CSRF token, the honeypot and the submit
	button, and leaves the questions to whoever needs them.

	Add fields inside the existing `<form>`. Do not add a second one — a nested
	form does not submit, and the browser will not tell you so.
--->
<section class="section">
	<div class="wrap">
		<div class="stack" style="margin-bottom:32px">
			<span class="eyebrow">Instructions</span>
			<h1>Your details</h1>
			<p class="lead">
				Answer what you can. Nothing here is final, and a lawyer reviews every
				answer before anything is drawn up.
			</p>
		</div>

		<cfif args.errors.len()>
			<div class="form-errors" role="alert">
				<cfloop array="#args.errors#" index="problem">
					<p>#encodeForHTML( problem )#</p>
				</cfloop>
			</div>
		</cfif>

		<form method="post" action="#xmlFormat( args.action )#" style="max-width:40rem">
			<input type="hidden" name="csrfToken" value="#xmlFormat( args.csrfToken )#">

			<div class="hp" aria-hidden="true">
				<label for="#xmlFormat( args.honeypotField )#">Leave this blank</label>
				<input type="text" id="#xmlFormat( args.honeypotField )#"
				       name="#xmlFormat( args.honeypotField )#" tabindex="-1" autocomplete="off">
			</div>

			<!--- Questionnaire fields go here. --->

			<cfif len( args.recaptchaSiteKey ?: "" )>
				<div class="g-recaptcha" data-sitekey="#xmlFormat( args.recaptchaSiteKey )#" style="margin:20px 0"></div>
				<script src="https://www.google.com/recaptcha/api.js" async defer></script>
			</cfif>

			<button type="submit" class="btn">Submit</button>
		</form>
	</div>
</section>
</cfoutput>
