<cfoutput>
<!---
	One field of an author-defined form. Expects `local.formField` and
	`local.formValues`.

	Core's, not a theme's, and its own file for the reason `_link.cfm` is:
	nine input types written inline would be nine places to forget an
	`encodeForHTMLAttribute`, and a tenth type would mean editing every theme
	that ever copied it.

	A theme that wants its own markup supplies a `form` view and does not
	include this. A theme that only wants its own *styling* should leave it
	alone and use the classes.
--->
<!---
	Attribute values use `xmlFormat`, not `encodeForHTMLAttribute`. Both are
	safe inside a quoted attribute; the aggressive one turns every space into
	`&##x20;`, which renders correctly and makes the page source unreadable.
	The same call was made for the SEO meta tags and for shortcode escaping.
--->
<cfset local.fieldKey   = local.formField.getFieldKey()>
<cfset local.fieldId    = "f_" & local.formField.getId()>
<cfset local.fieldType  = local.formField.getFieldType()>
<cfset local.fieldValue = local.formValues[ local.fieldKey ] ?: "">
<cfset local.fieldChosen = isArray( local.fieldValue ) ? local.fieldValue : listToArray( toString( local.fieldValue ), ",", false, true )>
<cfset local.fieldMax   = isNull( local.formField.getMaxLength() ) ? 0 : local.formField.getMaxLength()>

<div class="cms-field cms-field--#xmlFormat( local.fieldType )#">
	<!---
		A group of radios or checkboxes has no single control to point a
		`<label for>` at, so it gets a `<fieldset>` and a `<legend>` instead —
		which is what tells a screen reader that the options belong together.
	--->
	<cfif listFindNoCase( "radio,checkbox", local.fieldType )>
		<fieldset class="cms-field__group">
			<legend>
				#encodeForHTML( local.formField.getLabel() )#<cfif local.formField.getIsRequired()> <span aria-hidden="true">*</span></cfif>
			</legend>

			<cfif len( local.formField.getHelpText() ?: "" )>
				<p class="cms-field__help">#encodeForHTML( local.formField.getHelpText() )#</p>
			</cfif>

			<cfloop array="#local.formField.getOptions()#" index="local.formOption">
				<label class="cms-field__choice">
					<input type="#xmlFormat( local.fieldType )#"
					       name="#xmlFormat( local.fieldKey )#"
					       value="#xmlFormat( local.formOption )#"
					       <cfif arrayContains( local.fieldChosen, local.formOption )>checked</cfif>>
					#encodeForHTML( local.formOption )#
				</label>
			</cfloop>
		</fieldset>
	<cfelse>
		<label for="#xmlFormat( local.fieldId )#">
			#encodeForHTML( local.formField.getLabel() )#<cfif local.formField.getIsRequired()> <span aria-hidden="true">*</span></cfif>
		</label>

		<cfif len( local.formField.getHelpText() ?: "" )>
			<p class="cms-field__help" id="#xmlFormat( local.fieldId )#_help">#encodeForHTML( local.formField.getHelpText() )#</p>
		</cfif>

		<cfswitch expression="#local.fieldType#">
			<cfcase value="textarea">
				<textarea id="#xmlFormat( local.fieldId )#"
				          name="#xmlFormat( local.fieldKey )#"
				          rows="6"
				          <cfif local.fieldMax>maxlength="#local.fieldMax#"</cfif>
				          <cfif local.formField.getIsRequired()>required</cfif>
				          <cfif len( local.formField.getPlaceholder() ?: "" )>placeholder="#xmlFormat( local.formField.getPlaceholder() )#"</cfif>
				          <cfif len( local.formField.getHelpText() ?: "" )>aria-describedby="#xmlFormat( local.fieldId )#_help"</cfif>
				>#encodeForHTML( toString( local.fieldValue ) )#</textarea>
			</cfcase>

			<cfcase value="select">
				<select id="#xmlFormat( local.fieldId )#"
				        name="#xmlFormat( local.fieldKey )#"
				        <cfif local.formField.getIsRequired()>required</cfif>
				        <cfif len( local.formField.getHelpText() ?: "" )>aria-describedby="#xmlFormat( local.fieldId )#_help"</cfif>>
					<!--- An empty first option, so "not answered yet" is a state
					      the control can actually be in and `required` means
					      something. --->
					<option value="">#encodeForHTML( local.formField.getPlaceholder() ?: "Choose one" )#</option>
					<cfloop array="#local.formField.getOptions()#" index="local.formOption">
						<option value="#xmlFormat( local.formOption )#"
						        <cfif toString( local.fieldValue ) eq local.formOption>selected</cfif>>#encodeForHTML( local.formOption )#</option>
					</cfloop>
				</select>
			</cfcase>

			<cfdefaultcase>
				<input type="#xmlFormat( local.formFieldTypes.inputTypeFor( local.fieldType ) )#"
				       id="#xmlFormat( local.fieldId )#"
				       name="#xmlFormat( local.fieldKey )#"
				       value="#xmlFormat( toString( local.fieldValue ) )#"
				       <cfif local.fieldMax>maxlength="#local.fieldMax#"</cfif>
				       <cfif local.formField.getIsRequired()>required</cfif>
				       <cfif len( local.formField.getPlaceholder() ?: "" )>placeholder="#xmlFormat( local.formField.getPlaceholder() )#"</cfif>
				       <cfif len( local.formField.getHelpText() ?: "" )>aria-describedby="#xmlFormat( local.fieldId )#_help"</cfif>>
			</cfdefaultcase>
		</cfswitch>
	</cfif>
</div>
</cfoutput>
