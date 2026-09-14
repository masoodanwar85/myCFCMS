<cfoutput>
<cfset editing = isObject( prc.location )>
<h1>#editing ? "Edit location" : "New location"#</h1>
<p class="sub">A suburb or town name shown under a service on the Service Locations page.</p>

<form method="post" action="#editing ? '/admin/serviceareas/updateLocation/' & prc.location.getId() : '/admin/serviceareas/createLocation'#">
	<input type="hidden" name="csrfToken" value="#encodeForHTMLAttribute( prc.csrfToken )#">

	<div class="grid2">
		<div>
			<label for="name">Name</label>
			<input type="text" id="name" name="name" required
			       value="#editing ? encodeForHTMLAttribute( prc.location.getName() ) : ''#">
		</div>
		<div>
			<label for="slug">Slug</label>
			<input type="text" id="slug" name="slug" placeholder="derived from the name"
			       value="#editing ? encodeForHTMLAttribute( prc.location.getSlug() ) : ''#">
		</div>
	</div>

	<div class="grid2">
		<div>
			<label for="region">Region (optional)</label>
			<input type="text" id="region" name="region" placeholder="Blue Mountains"
			       value="#editing ? encodeForHTMLAttribute( prc.location.getRegion() ?: '' ) : ''#">
		</div>
		<div>
			<label for="href">Link (optional)</label>
			<input type="text" id="href" name="href" placeholder="/locations/blue-mountains/katoomba"
			       value="#editing ? encodeForHTMLAttribute( prc.location.getHref() ?: '' ) : ''#">
		</div>
	</div>

	<div class="grid2">
		<div>
			<label for="sortOrder">Sort order</label>
			<input type="number" id="sortOrder" name="sortOrder"
			       value="#editing ? encodeForHTMLAttribute( prc.location.getSortOrder() ) : '0'#">
		</div>
	</div>

	<div class="checks">
		<label>
			<input type="checkbox" name="active"<cfif !editing || prc.location.getActive()> checked</cfif>>
			Active
		</label>
	</div>

	<p>
		<button type="submit" class="btn">#editing ? "Save location" : "Create location"#</button>
		<a class="btn secondary" href="/admin/serviceareas">Cancel</a>
	</p>
</form>
</cfoutput>
