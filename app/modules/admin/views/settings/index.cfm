<cfoutput>
<h1>Settings</h1>
<p class="sub">Configuration for #encodeForHTML( prc.currentSite.getName() )#.</p>

<h2>Site</h2>
<form method="post" action="/admin/settings/update">
	<input type="hidden" name="csrfToken" value="#encodeForHTMLAttribute( prc.csrfToken )#">
	<div class="grid2">
		<div>
			<label for="name">Name</label>
			<input type="text" id="name" name="name" #prc.canUpdate ? '' : 'disabled'#
			       value="#encodeForHTMLAttribute( prc.currentSite.getName() )#">
		</div>
		<div>
			<label for="status">Status</label>
			<select id="status" name="status" #prc.canUpdate ? '' : 'disabled'#>
				<cfloop array="#[ 'active', 'inactive' ]#" index="s">
					<option value="#s#" #prc.currentSite.getStatus() eq s ? 'selected' : ''#>#s#</option>
				</cfloop>
			</select>
		</div>
		<div>
			<label for="timezone">Timezone</label>
			<input type="text" id="timezone" name="timezone" #prc.canUpdate ? '' : 'disabled'#
			       value="#encodeForHTMLAttribute( prc.currentSite.getTimezone() )#">
		</div>
		<div>
			<label for="locale">Locale</label>
			<input type="text" id="locale" name="locale" #prc.canUpdate ? '' : 'disabled'#
			       value="#encodeForHTMLAttribute( prc.currentSite.getLocale() )#">
		</div>
	</div>

	<cfif prc.canUpdate>
		<label style="display:flex;gap:.4rem;align-items:center;color:var(--ink)">
			<input type="checkbox" name="confirmOffline" value="yes" style="width:auto">
			I understand that setting the status to <strong>inactive</strong> takes this site offline.
		</label>
		<div class="actions-bar"><button type="submit">Save site</button></div>
	<cfelse>
		<p class="muted">You do not have permission to change these.</p>
	</cfif>
</form>

<h2>Theme</h2>
<form method="post" action="/admin/settings/theme">
	<input type="hidden" name="csrfToken" value="#encodeForHTMLAttribute( prc.csrfToken )#">
	<label for="theme">Active theme</label>
	<select id="theme" name="theme" #prc.canTheme ? '' : 'disabled'#>
		<cfloop array="#prc.themes#" index="t">
			<option value="#encodeForHTMLAttribute( t.getSlug() )#" #t.getSlug() eq prc.theme.getSlug() ? 'selected' : ''#>
				#encodeForHTML( t.getTitle() )# (#encodeForHTML( t.getSlug() )#)
			</option>
		</cfloop>
	</select>
	<cfif prc.canTheme>
		<div class="actions-bar"><button type="submit">Change theme</button></div>
	</cfif>
</form>

<cfif prc.canSeo>
<h2>Search engines</h2>
<form method="post" action="/admin/settings/seo">
	<input type="hidden" name="csrfToken" value="#encodeForHTMLAttribute( prc.csrfToken )#">

	<div class="checks">
		<label>
			<input type="checkbox" name="indexable"<cfif prc.seoIndexable> checked</cfif>>
			Allow search engines to index this site
		</label>
	</div>
	<p class="muted" style="font-size:.8rem">
		Turning this off makes <code>/robots.txt</code> refuse every crawler, marks every page
		<code>noindex</code>, and stops serving <code>/sitemap.xml</code> &mdash; for a staging or
		holding site. It is a request, not a lock: it keeps honest crawlers out, not people.
	</p>

	<div class="grid2">
		<div>
			<label for="baseUrl">Site address</label>
			<input type="text" id="baseUrl" name="baseUrl"
			       value="#encodeForHTMLAttribute( prc.seoBaseUrlSetting )#"
			       placeholder="#encodeForHTMLAttribute( prc.seoBaseUrl )#">
			<p class="muted" style="font-size:.8rem">
				Used for canonical tags, social previews and the sitemap. Leave blank to use the
				primary domain &mdash; currently
				<cfif len( prc.seoBaseUrl )><code>#encodeForHTML( prc.seoBaseUrl )#</code><cfelse><strong>none, so no canonical tags are emitted</strong></cfif>.
				Set it outright if TLS is terminated by a proxy that does not send
				<code>X-Forwarded-Proto</code>.
			</p>
		</div>
		<div>
			<label for="defaultImage">Default social image</label>
			<input type="text" id="defaultImage" name="defaultImage"
			       value="#encodeForHTMLAttribute( prc.seoDefaultImage )#"
			       placeholder="/media/2026/08/preview.png">
			<p class="muted" style="font-size:.8rem">
				Shown when a page has no image of its own. A path from the media library, or a full address.
			</p>
		</div>
	</div>

	<label for="defaultDescription">Default description</label>
	<input type="text" id="defaultDescription" name="defaultDescription" maxlength="300"
	       value="#encodeForHTMLAttribute( prc.seoDefaultDescription )#">
	<p class="muted" style="font-size:.8rem">
		Used for any page that has not been given its own.
	</p>

	<div class="actions-bar"><button type="submit">Save search settings</button></div>
</form>
</cfif>

<cfif prc.canTheme>
<h2>reCAPTCHA</h2>
<form method="post" action="/admin/settings/recaptcha">
	<input type="hidden" name="csrfToken" value="#encodeForHTMLAttribute( prc.csrfToken )#">

	<p class="muted" style="font-size:.85rem">
		Protects the public forms on this site &mdash; the contact form today, and anything
		else that accepts input later. Keys come from
		<a href="https://www.google.com/recaptcha/admin" target="_blank" rel="noopener">Google reCAPTCHA</a>;
		choose <strong>v2 &ldquo;I&rsquo;m not a robot&rdquo;</strong>.
		<cfif prc.recaptchaActive>
			<span class="pill on">active</span>
		<cfelse>
			<span class="pill off">not active</span> &mdash; both keys are needed.
		</cfif>
	</p>

	<div class="grid2">
		<div>
			<label for="recaptchaSiteKey">Site key</label>
			<input type="text" id="recaptchaSiteKey" name="recaptchaSiteKey"
			       value="#encodeForHTMLAttribute( prc.recaptchaSiteKey )#"
			       autocomplete="off" spellcheck="false">
			<p class="muted" style="font-size:.8rem">
				Public. It appears in the page source, which is how the widget works.
			</p>
		</div>
		<div>
			<label for="recaptchaSecretKey">
				Secret key
				<cfif prc.recaptchaHasSecret><span class="pill on">set</span><cfelse><span class="pill off">not set</span></cfif>
			</label>
			<!---
				Never rendered back. The field is always blank, and a blank value
				means "leave the stored one alone" — otherwise opening this page
				and pressing save would wipe the secret.
			--->
			<input type="password" id="recaptchaSecretKey" name="recaptchaSecretKey"
			       placeholder="#prc.recaptchaHasSecret ? 'unchanged' : 'paste the secret key'#"
			       autocomplete="new-password" spellcheck="false">
			<p class="muted" style="font-size:.8rem">
				Shared with Google and never shown again once saved. Leave blank to keep the current one.
			</p>
			<cfif prc.recaptchaHasSecret>
				<div class="checks">
					<label><input type="checkbox" name="clearRecaptchaSecret"> Remove the stored secret</label>
				</div>
			</cfif>
		</div>
	</div>

	<p class="muted" style="font-size:.8rem">
		While reCAPTCHA is active, a submission that cannot be verified is refused &mdash; including
		when Google itself cannot be reached. Clear a key to turn it off.
	</p>

	<div class="actions-bar"><button type="submit">Save reCAPTCHA settings</button></div>
</form>
</cfif>

<h2>Domains</h2>
<table>
	<thead><tr><th>Domain</th><th>Primary</th><th>Active</th><th></th></tr></thead>
	<tbody>
		<cfloop array="#prc.domains#" index="d">
			<tr>
				<td><code>#encodeForHTML( d.getDomain() )#</code></td>
				<td><cfif d.getIsPrimary()><span class="pill on">primary</span><cfelse><span class="muted">&mdash;</span></cfif></td>
				<td><span class="pill #d.getIsActive() ? 'on' : 'off'#">#d.getIsActive() ? "active" : "inactive"#</span></td>
				<td class="actions">
					<cfif prc.canDomains>
						<cfif !d.getIsPrimary()>
							<form class="inline" method="post" action="/admin/settings/primaryDomain">
								<input type="hidden" name="csrfToken" value="#encodeForHTMLAttribute( prc.csrfToken )#">
								<input type="hidden" name="domain" value="#encodeForHTMLAttribute( d.getDomain() )#">
								<button type="submit" class="ico">Make primary</button>
							</form>
						</cfif>
						<form class="inline" method="post" action="/admin/settings/toggleDomain/#d.getId()#">
							<input type="hidden" name="csrfToken" value="#encodeForHTMLAttribute( prc.csrfToken )#">
							<button type="submit" class="ico">#d.getIsActive() ? "Deactivate" : "Activate"#</button>
						</form>
						<form class="inline" method="post" action="/admin/settings/removeDomain/#d.getId()#"
						      onsubmit="return confirm('Remove #encodeForJavaScript( d.getDomain() )#?')">
							<input type="hidden" name="csrfToken" value="#encodeForHTMLAttribute( prc.csrfToken )#">
							<button type="submit" class="ico danger">Remove</button>
						</form>
					</cfif>
				</td>
			</tr>
		</cfloop>
	</tbody>
</table>

<cfif prc.canDomains>
	<form class="narrow" method="post" action="/admin/settings/addDomain">
		<input type="hidden" name="csrfToken" value="#encodeForHTMLAttribute( prc.csrfToken )#">
		<label for="domain">Add a domain</label>
		<input type="text" id="domain" name="domain" placeholder="client.com" required>
		<label style="display:flex;gap:.4rem;align-items:center;color:var(--ink)">
			<input type="checkbox" name="isPrimary" value="yes" style="width:auto"> Make this the primary domain
		</label>
		<div class="actions-bar"><button type="submit">Add domain</button></div>
	</form>
</cfif>
</cfoutput>
