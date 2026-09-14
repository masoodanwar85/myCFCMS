<cfoutput>
<cfset editing = isObject( prc.service )>
<h1>#editing ? "Edit service" : "New service"#</h1>
<p class="sub">A tab on the Service Locations page. It appears only after at least one location is ticked.</p>

<form method="post" action="#editing ? '/admin/serviceareas/updateService/' & prc.service.getId() : '/admin/serviceareas/createService'#">
	<input type="hidden" name="csrfToken" value="#encodeForHTMLAttribute( prc.csrfToken )#">

	<div class="grid2">
		<div>
			<label for="name">Name</label>
			<input type="text" id="name" name="name" required
			       value="#editing ? encodeForHTMLAttribute( prc.service.getName() ) : ''#">
		</div>
		<div>
			<label for="slug">Slug</label>
			<input type="text" id="slug" name="slug" placeholder="derived from the name"
			       value="#editing ? encodeForHTMLAttribute( prc.service.getSlug() ) : ''#">
		</div>
	</div>

	<div class="grid2">
		<div>
			<label for="href">Link (optional)</label>
			<input type="text" id="href" name="href" placeholder="/legal-services/wills"
			       value="#editing ? encodeForHTMLAttribute( prc.service.getHref() ?: '' ) : ''#">
		</div>
		<div>
			<label for="sortOrder">Sort order</label>
			<input type="number" id="sortOrder" name="sortOrder"
			       value="#editing ? encodeForHTMLAttribute( prc.service.getSortOrder() ) : '0'#">
		</div>
	</div>

	<div class="checks">
		<label>
			<input type="checkbox" name="active"<cfif !editing || prc.service.getActive()> checked</cfif>>
			Active (eligible to show on the public page)
		</label>
	</div>

	<label>Locations</label>
	<cfif !prc.locations.len()>
		<p class="muted">Add towns on the Locations tab first, then attach them here.</p>
	<cfelse>
		<div class="checks">
			<cfloop array="#prc.locations#" index="loc">
				<label>
					<input type="checkbox" name="locationIds" value="#loc.getId()#"
						<cfif arrayFind( prc.selected, loc.getId() )> checked</cfif>>
					#encodeForHTML( loc.getName() )#
					<cfif len( loc.getRegion() )><span class="muted">(#encodeForHTML( loc.getRegion() )#)</span></cfif>
				</label>
			</cfloop>
		</div>
	</cfif>

	<p>
		<button type="submit" class="btn">#editing ? "Save service" : "Create service"#</button>
		<a class="btn secondary" href="/admin/serviceareas">Cancel</a>
	</p>
</form>
</cfoutput>
