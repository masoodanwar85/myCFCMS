<cfoutput>
<!---
	The real contact form, styled as the mockup's enquiry panel.

	The mockup drew a bespoke form with a state dropdown and a row of "what do
	you need help with" checkboxes. Those are not fields this form has, and
	inventing them in markup would produce inputs that submit into nothing —
	a form that looks like it works and quietly drops half of what is typed.
	The fields below are the ones the Contact module actually stores, so every
	answer reaches the inbox. Extra fields belong in a Forms-module form, which
	can be authored with exactly those questions.

	`args.embedded` is true when this comes from the `[contact-form]` shortcode
	rather than from `/contact`. The page around it already has a heading and a
	wrapper, so both are dropped — a second <h1> would give the page two
	competing titles.
--->
<cfif !( args.embedded ?: false )>
<section class="section section--blue">
	<div class="wrap contact">
		<div class="contact__intro">
			<span class="eyebrow">Get in touch</span>
			<h1>Tell us what has happened. We will tell you what comes next.</h1>
			<cfif len( args.form.getIntro() ?: "" )>
				<p class="lead">#encodeForHTML( args.form.getIntro() )#</p>
			</cfif>
		</div>

		<div class="contact__panel">
</cfif>

	<cfif ( args.embedded ?: false ) and len( args.form.getIntro() ?: "" )>
		<p class="lead">#encodeForHTML( args.form.getIntro() )#</p>
	</cfif>

	<cfif args.errors.len()>
		<div class="form-errors" role="alert">
			<cfloop array="#args.errors#" index="problem">
				<p>#encodeForHTML( problem )#</p>
			</cfloop>
		</div>
	</cfif>

	<form method="post" action="#xmlFormat( args.action )#">
		<input type="hidden" name="csrfToken" value="#xmlFormat( args.csrfToken )#">
		<input type="hidden" name="form" value="#encodeForHTMLAttribute( args.form.getSlug() )#">

		<!--- Left empty by a person; filled in by a bot. Hidden from sighted
		      users and from screen readers alike. --->
		<div class="hp" aria-hidden="true">
			<label for="#xmlFormat( args.honeypotField )#">Leave this blank</label>
			<input type="text" id="#xmlFormat( args.honeypotField )#"
			       name="#xmlFormat( args.honeypotField )#" tabindex="-1" autocomplete="off">
		</div>

		<div class="field">
			<label for="name">Your name</label>
			<input type="text" id="name" name="name" required maxlength="150"
			       autocomplete="name" value="#xmlFormat( args.values.name ?: '' )#">
		</div>

		<div class="field">
			<label for="email">Your email</label>
			<input type="email" id="email" name="email" required maxlength="191"
			       autocomplete="email" value="#xmlFormat( args.values.email ?: '' )#">
		</div>

		<div class="field">
			<label for="subject">Subject</label>
			<input type="text" id="subject" name="subject" maxlength="255"
			       value="#xmlFormat( args.values.subject ?: '' )#">
		</div>

		<div class="field">
			<label for="message">How can we help?</label>
			<textarea id="message" name="message" required rows="7" maxlength="10000">#encodeForHTML( args.values.message ?: '' )#</textarea>
		</div>

		<cfif len( args.recaptchaSiteKey ?: "" )>
			<!---
				Rendered only when the site has both keys. `data-sitekey` is
				public by design — the widget cannot work otherwise — and the
				secret never reaches the browser. `async defer` so a slow or
				blocked Google does not hold up the page; the server refuses an
				unverified submission either way.
			--->
			<div class="g-recaptcha" data-sitekey="#xmlFormat( args.recaptchaSiteKey )#" style="margin:20px 0"></div>
			<script src="https://www.google.com/recaptcha/api.js" async defer></script>
		</cfif>

		<button type="submit" class="btn">Send my enquiry</button>

		<p class="form-note">
			Sending this form does not create a lawyer&ndash;client relationship.
			Your details are kept confidential.
		</p>
	</form>

<cfif !( args.embedded ?: false )>
		</div>
	</div>
</section>
</cfif>
</cfoutput>
