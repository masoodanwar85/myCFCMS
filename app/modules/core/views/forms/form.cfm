<cfoutput>
<!---
	The default rendering of an author-defined form.

	Core's fallback, used whenever the site's theme has no `form` view of its
	own — which is the normal case, because a theme written before a form
	existed cannot have a view for it. A theme takes over by supplying
	`views/form.cfm`; the args are the contract.

	Deliberately unstyled beyond structural classes. Themes differ, and markup
	that guessed at a look would be wrong everywhere.
--->
<cfset local.formFieldTypes = application.wirebox.getInstance( "FieldTypes@forms" )>
<cfset local.formValues     = args.values>

<div class="cms-form" data-form="#xmlFormat( args.form.getSlug() )#">
	<cfif len( args.form.getIntro() ?: "" )>
		<div class="cms-form__intro">#args.form.getIntro()#</div>
	</cfif>

	<cfif args.errors.len()>
		<div class="cms-form__errors" role="alert">
			<cfloop array="#args.errors#" index="local.formProblem">
				<p>#encodeForHTML( local.formProblem )#</p>
			</cfloop>
		</div>
	</cfif>

	<form method="post" action="#xmlFormat( args.action )#" class="cms-form__form">
		<input type="hidden" name="csrfToken" value="#xmlFormat( args.csrfToken )#">
		<!--- Which form is answering. Named distinctly from Contact's marker so
		      a page carrying both does not have two modules claiming one POST. --->
		<input type="hidden" name="#xmlFormat( args.markerField )#" value="#xmlFormat( args.form.getSlug() )#">

		<!--- Left empty by a person; filled in by a bot. Hidden from sighted
		      users and from screen readers alike. --->
		<div style="position:absolute;left:-9999px" aria-hidden="true">
			<label for="#xmlFormat( args.honeypotField )#">Leave this blank</label>
			<input type="text" id="#xmlFormat( args.honeypotField )#" name="#xmlFormat( args.honeypotField )#"
			       tabindex="-1" autocomplete="off">
		</div>

		<cfloop array="#args.fields#" index="local.formField">
			<cfinclude template="/core/views/forms/_field.cfm">
		</cfloop>

		<cfif !args.fields.len()>
			<p class="cms-form__empty">This form has no fields yet.</p>
		</cfif>

		<cfif len( args.recaptchaSiteKey ?: "" )>
			<!--- Rendered only when the site has both keys, so a theme never
			      shows a widget this site could not verify. --->
			<div class="g-recaptcha" data-sitekey="#xmlFormat( args.recaptchaSiteKey )#"></div>
			<script src="https://www.google.com/recaptcha/api.js" async defer></script>
		</cfif>

		<div class="cms-form__actions">
			<button type="submit">#encodeForHTML( args.form.getSubmitLabel() )#</button>
		</div>
	</form>
</div>
</cfoutput>
