<cfoutput>
<h1>Service areas</h1>
<p class="sub">
	Services and towns shown on the Service Locations page for #encodeForHTML( prc.currentSite.getName() )#.
	This list does not change the public Legal Services menu.
</p>

<div class="tabs">
	<input type="radio" name="areasTab" id="tab-services" checked>
	<label for="tab-services">Services</label>

	<input type="radio" name="areasTab" id="tab-locations">
	<label for="tab-locations">Locations</label>

	<section class="tab-panel" data-for="tab-services">
		<div class="adm-toolbar">
			<cfif prc.canManage><a class="btn" href="/admin/serviceareas/newService">+ New service</a></cfif>
			<a class="btn secondary" href="/service-locations" target="_blank" rel="noopener">View page &nearr;</a>
			<span class="adm-count">#prc.services.len()# services</span>
		</div>

		<table>
			<thead>
				<tr>
					<th>Service</th>
					<th>URL</th>
					<th class="c">Locations</th>
					<th class="c">Status</th>
					<th class="r">Actions</th>
				</tr>
			</thead>
			<tbody>
				<cfif !prc.services.len()>
					<tr><td colspan="5" class="muted">No services yet.</td></tr>
				</cfif>
				<cfloop array="#prc.services#" index="svc">
					<tr class="#svc.getActive() ? '' : 'is-off'#">
						<td>
							<cfif prc.canManage>
								<a href="/admin/serviceareas/editService/#svc.getId()#"><strong>#encodeForHTML( svc.getName() )#</strong></a>
							<cfelse>
								<strong>#encodeForHTML( svc.getName() )#</strong>
							</cfif>
						</td>
						<td class="mono">#len( svc.getHref() ) ? encodeForHTML( svc.getHref() ) : "&mdash;"#</td>
						<td class="c">#svc.getLocationCount()#</td>
						<td class="c">
							<span class="pill #svc.getActive() ? 'on' : 'off'#">#svc.getActive() ? "Active" : "Hidden"#</span>
						</td>
						<td class="r nowrap">
							<cfif prc.canManage>
								<a class="ico" href="/admin/serviceareas/editService/#svc.getId()#">Edit</a>
								<form class="inline" method="post" action="/admin/serviceareas/removeService/#svc.getId()#"
								      onsubmit="return confirm('Delete #encodeForJavaScript( svc.getName() )#?')">
									<input type="hidden" name="csrfToken" value="#encodeForHTMLAttribute( prc.csrfToken )#">
									<button type="submit" class="ico danger">Delete</button>
								</form>
							</cfif>
						</td>
					</tr>
				</cfloop>
			</tbody>
		</table>
		<p class="muted" style="font-size:.85rem">Only services with at least one active location appear on the public page.</p>
	</section>

	<section class="tab-panel" data-for="tab-locations">
		<div class="adm-toolbar">
			<cfif prc.canManage><a class="btn" href="/admin/serviceareas/newLocation">+ New location</a></cfif>
			<span class="adm-count">#prc.locations.len()# locations</span>
		</div>

		<table>
			<thead>
				<tr>
					<th>Town / suburb</th>
					<th>Region</th>
					<th>URL</th>
					<th class="c">Status</th>
					<th class="r">Actions</th>
				</tr>
			</thead>
			<tbody>
				<cfif !prc.locations.len()>
					<tr><td colspan="5" class="muted">No locations yet.</td></tr>
				</cfif>
				<cfloop array="#prc.locations#" index="loc">
					<tr class="#loc.getActive() ? '' : 'is-off'#">
						<td>
							<cfif prc.canManage>
								<a href="/admin/serviceareas/editLocation/#loc.getId()#"><strong>#encodeForHTML( loc.getName() )#</strong></a>
							<cfelse>
								<strong>#encodeForHTML( loc.getName() )#</strong>
							</cfif>
						</td>
						<td>#len( loc.getRegion() ) ? encodeForHTML( loc.getRegion() ) : "&mdash;"#</td>
						<td class="mono">#len( loc.getHref() ) ? encodeForHTML( loc.getHref() ) : "&mdash;"#</td>
						<td class="c">
							<span class="pill #loc.getActive() ? 'on' : 'off'#">#loc.getActive() ? "Active" : "Hidden"#</span>
						</td>
						<td class="r nowrap">
							<cfif prc.canManage>
								<a class="ico" href="/admin/serviceareas/editLocation/#loc.getId()#">Edit</a>
								<form class="inline" method="post" action="/admin/serviceareas/removeLocation/#loc.getId()#"
								      onsubmit="return confirm('Delete #encodeForJavaScript( loc.getName() )#?')">
									<input type="hidden" name="csrfToken" value="#encodeForHTMLAttribute( prc.csrfToken )#">
									<button type="submit" class="ico danger">Delete</button>
								</form>
							</cfif>
						</td>
					</tr>
				</cfloop>
			</tbody>
		</table>
	</section>
</div>
</cfoutput>
