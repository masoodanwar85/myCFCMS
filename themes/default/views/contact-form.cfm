<cfoutput>
<article data-view="default-contact-form">
	<h1>#encodeForHTML( args.form.getName() )#</h1>

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
		<p><button type="submit">Send message</button></p>
	</form>
</article>
</cfoutput>
