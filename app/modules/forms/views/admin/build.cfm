<cfoutput>
<h1>#encodeForHTML( prc.form.getName() )#</h1>
<p class="sub">
	<code>[form slug="#encodeForHTML( prc.form.getSlug() )#"]</code>
	&middot; #prc.responses# response<cfif prc.responses neq 1>s</cfif>
	<cfif prc.responses> &middot; <a href="/admin/forms?formId=#prc.form.getId()#">view</a></cfif>
</p>

<!---
	Two tabs: the fields an author builds, and the settings behind them. Fields
	first, because that is why anybody opens this screen.

	Panels are matched to radios by position; see the note in `_styles.cfm`
	before adding one.
--->
<div class="tabs">
	<input type="radio" name="formTab" id="tab-fields" checked>
	<label for="tab-fields">Fields</label>

	<input type="radio" name="formTab" id="tab-settings">
	<label for="tab-settings">Settings</label>

	<section class="tab-panel" data-for="tab-fields">
		<!---
			A list, not a stack of open forms. A form with a dozen fields was
			twelve full editors down the page, and finding the one you wanted
			meant scrolling past every other. Each row now says what the field
			is at a glance and opens in place when you want to change it.

			`<details>` rather than script: the panel is already in the DOM, it
			works with the keyboard for free, and browser find-in-page can still
			reach a closed one.
		--->
		<cfif !prc.fields.len()>
			<p class="muted">No fields yet. Add the first one below.</p>
		<cfelse>
			<div class="field-list">
				<cfloop array="#prc.fields#" index="field">
					<details class="field-item">
						<summary>
							<span class="field-item__order">#field.getSortOrder()#</span>
							<span class="field-item__label">#encodeForHTML( field.getLabel() )#</span>
							<code class="field-item__key">#encodeForHTML( field.getFieldKey() )#</code>
							<span class="pill off">#encodeForHTML( prc.typeLabels[ field.getFieldType() ] ?: field.getFieldType() )#</span>
							<cfif field.getIsRequired()><span class="pill on">required</span></cfif>
						</summary>

						<div class="field-item__body">
							<form method="post" action="/admin/forms/updateField/#field.getId()#">
								<input type="hidden" name="csrfToken" value="#encodeForHTMLAttribute( prc.csrfToken )#">

								<div class="grid3">
									<div>
										<label for="type#field.getId()#">Type</label>
										<select id="type#field.getId()#" name="fieldType">
											<cfloop array="#prc.fieldTypes#" index="t">
												<option value="#encodeForHTMLAttribute( t.key )#"
												        <cfif t.key eq field.getFieldType()>selected</cfif>>#encodeForHTML( t.label )#</option>
											</cfloop>
										</select>
									</div>
									<div>
										<label for="label#field.getId()#">Label</label>
										<input type="text" id="label#field.getId()#" name="label"
										       value="#encodeForHTMLAttribute( field.getLabel() )#">
									</div>
									<div>
										<label for="order#field.getId()#">Order</label>
										<input type="number" id="order#field.getId()#" name="sortOrder"
										       value="#field.getSortOrder()#">
									</div>
								</div>

								<div class="grid3">
									<div>
										<label for="ph#field.getId()#">Placeholder</label>
										<input type="text" id="ph#field.getId()#" name="placeholder"
										       value="#encodeForHTMLAttribute( field.getPlaceholder() ?: '' )#">
									</div>
									<div>
										<label for="help#field.getId()#">Help text</label>
										<input type="text" id="help#field.getId()#" name="helpText"
										       value="#encodeForHTMLAttribute( field.getHelpText() ?: '' )#">
									</div>
									<div>
										<label for="max#field.getId()#">Max length</label>
										<input type="number" id="max#field.getId()#" name="maxLength" min="0"
										       placeholder="no limit"
										       value="#isNull( field.getMaxLength() ) ? '' : field.getMaxLength()#">
									</div>
								</div>

								<cfif prc.typeHasOptions[ field.getFieldType() ] ?: false>
									<label for="opt#field.getId()#">Choices <span class="muted" style="font-weight:400">one per line</span></label>
									<textarea id="opt#field.getId()#" name="optionsText" rows="4">#encodeForHTML( field.getOptionsText() ?: '' )#</textarea>
								<cfelse>
									<!--- Carried through unchanged, so switching a field to a
									      choice type and back does not lose what was typed. --->
									<input type="hidden" name="optionsText" value="#encodeForHTMLAttribute( field.getOptionsText() ?: '' )#">
									<p class="muted" style="font-size:.8rem">
										Choices apply to dropdown, choose-one and choose-any fields.
										Change the type above to set them.
									</p>
								</cfif>

								<label style="display:flex;gap:.4rem;align-items:center;color:var(--ink)">
									<input type="checkbox" name="isRequired" value="yes" style="width:auto"
									       #field.getIsRequired() ? 'checked' : ''#>
									Required
								</label>

								<div class="actions-bar">
									<button type="submit">Save field</button>
								</div>
							</form>

							<form method="post" action="/admin/forms/deleteField/#field.getId()#"
							      onsubmit="return confirm('Remove #encodeForJavaScript( field.getLabel() )#? Answers already given stay on their responses.')">
								<input type="hidden" name="csrfToken" value="#encodeForHTMLAttribute( prc.csrfToken )#">
								<button type="submit" class="ico danger">Remove field</button>
							</form>
						</div>
					</details>
				</cfloop>
			</div>
		</cfif>

		<h2>Add a field</h2>
		<!---
			The same inputs as the editor above, deliberately. This form used to
			offer type, label and name only, so a placeholder or a piece of help
			text could not be set until *after* the field existed — an author had
			to add it, then reopen it to finish it.
		--->
		<form method="post" action="/admin/forms/addField/#prc.form.getId()#">
			<input type="hidden" name="csrfToken" value="#encodeForHTMLAttribute( prc.csrfToken )#">

			<div class="grid3">
				<div>
					<label for="newType">Type</label>
					<select id="newType" name="fieldType">
						<cfloop array="#prc.fieldTypes#" index="t">
							<option value="#encodeForHTMLAttribute( t.key )#">#encodeForHTML( t.label )#</option>
						</cfloop>
					</select>
				</div>
				<div>
					<label for="newLabel">Label</label>
					<input type="text" id="newLabel" name="label" placeholder="Your name" required>
				</div>
				<div>
					<label for="newKey">Name <span class="muted" style="font-weight:400">optional</span></label>
					<input type="text" id="newKey" name="fieldKey" placeholder="from the label">
				</div>
			</div>

			<div class="grid3">
				<div>
					<label for="newPlaceholder">Placeholder</label>
					<input type="text" id="newPlaceholder" name="placeholder" placeholder="shown in the empty box">
				</div>
				<div>
					<label for="newHelp">Help text</label>
					<input type="text" id="newHelp" name="helpText" placeholder="shown under the label">
				</div>
				<div>
					<label for="newMax">Max length</label>
					<input type="number" id="newMax" name="maxLength" min="0" placeholder="no limit">
				</div>
			</div>

			<label for="newOptions">Choices <span class="muted" style="font-weight:400">one per line</span></label>
			<textarea id="newOptions" name="optionsText" rows="3" placeholder="Morning&##10;Afternoon&##10;Evening"></textarea>
			<p class="muted" style="font-size:.8rem">
				Needed by dropdown, choose-one and choose-any fields. Ignored by the rest.
			</p>

			<label style="display:flex;gap:.4rem;align-items:center;color:var(--ink)">
				<input type="checkbox" name="isRequired" value="yes" style="width:auto"> Required
			</label>

			<div class="actions-bar"><button type="submit">Add field</button></div>
		</form>

		<p class="muted" style="font-size:.8rem">
			A field's <strong>name</strong> is fixed once it exists: responses are recorded under it,
			and changing it would file them under a name the form no longer has. The label is free to
			change at any time &mdash; old responses keep the label they were given.
		</p>
	</section>

	<section class="tab-panel" data-for="tab-settings">
		<form method="post" action="/admin/forms/update/#prc.form.getId()#">
			<input type="hidden" name="csrfToken" value="#encodeForHTMLAttribute( prc.csrfToken )#">

			<div class="grid2">
				<div>
					<label for="name">Name</label>
					<input type="text" id="name" name="name" value="#encodeForHTMLAttribute( prc.form.getName() )#">
				</div>
				<div>
					<label for="rcpt">Send responses to</label>
					<input type="email" id="rcpt" name="recipientEmail"
					       value="#encodeForHTMLAttribute( prc.form.getRecipientEmail() ?: '' )#">
				</div>
			</div>

			<label for="intro">Intro shown above the form</label>
			<input type="text" id="intro" name="intro" value="#encodeForHTMLAttribute( prc.form.getIntro() ?: '' )#">

			<div class="grid2">
				<div>
					<label for="submitLabel">Button text</label>
					<input type="text" id="submitLabel" name="submitLabel"
					       value="#encodeForHTMLAttribute( prc.form.getSubmitLabel() )#">
				</div>
				<div>
					<label for="typ">Thank-you page <span class="muted" style="font-weight:400">optional</span></label>
					<input type="text" id="typ" name="thankYouPath" placeholder="leave blank to stay on the page"
					       value="#encodeForHTMLAttribute( prc.form.getThankYouPath() ?: '' )#">
				</div>
			</div>

			<label for="msg">Message shown after sending</label>
			<input type="text" id="msg" name="successMessage"
			       value="#encodeForHTMLAttribute( prc.form.getSuccessMessage() )#">
			<p class="muted" style="font-size:.8rem">
				Shown where the form stood. Set a thank-you page instead when you need the visitor to
				land on a real URL &mdash; advertising conversion tracking fires on a page being
				loaded, and a message swapped in by the server never produces one.
			</p>

			<label style="display:flex;gap:.4rem;align-items:center;color:var(--ink)">
				<input type="checkbox" name="storeSubmissions" value="yes" style="width:auto"
				       #prc.form.getStoreSubmissions() ? 'checked' : ''#>
				Keep responses in the CMS
			</label>
			<p class="muted" style="font-size:.8rem">
				Untick for a form that should only send an email &mdash; responses are still validated
				and still delivered, they simply leave no record here. Existing responses are not
				removed by unticking it.
			</p>

			<label style="display:flex;gap:.4rem;align-items:center;color:var(--ink)">
				<input type="checkbox" name="isActive" value="yes" style="width:auto"
				       #prc.form.getIsActive() ? 'checked' : ''#>
				Accepting responses
			</label>
			<p class="muted" style="font-size:.8rem">
				Unticking hides the form from every page it is on, rather than showing one that
				refuses what is sent to it.
			</p>

			<div class="actions-bar">
				<button type="submit">Save settings</button>
				<a class="btn secondary" href="/admin/forms/forms">Back to forms</a>
			</div>
		</form>
	</section>
</div>
</cfoutput>
