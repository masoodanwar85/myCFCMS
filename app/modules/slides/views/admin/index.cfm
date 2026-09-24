<cfoutput>
<h1>Slides</h1>
<p class="sub">
		The homepage slider for #encodeForHTML( prc.currentSite.getName() )#.
		Add as many slides as you need — each has its own image and overlay HTML.
		Published slides move in sort order. Other pages use <code>[hero-slider]</code>.
	</p>

<div class="adm-toolbar">
	<cfif prc.canManage><a class="btn" href="/admin/slides/new">+ New slide</a></cfif>
	<span class="adm-count">#prc.slides.len()# slides</span>
</div>

<table>
	<thead>
		<tr>
			<th style="width:8%">Order</th>
			<th style="width:7%"></th>
			<th>Overlay</th>
			<th>Position</th>
			<th class="c">Status</th>
			<th class="r">Actions</th>
		</tr>
	</thead>
	<tbody>
		<cfif !prc.slides.len()>
			<tr><td colspan="6" class="muted">No slides yet.</td></tr>
		</cfif>
		<cfloop array="#prc.slides#" index="slide">
			<tr class="#slide.getIsPublished() ? '' : 'is-off'#">
				<td class="muted">#encodeForHTML( slide.getSortOrder() )#</td>
				<td>
					<cfif len( slide.getImageUrl() )>
						<img src="#encodeForHTMLAttribute( slide.getImageUrl() )#"
						     alt="" style="width:3.2rem;height:2rem;object-fit:cover;border-radius:4px;display:block">
					</cfif>
				</td>
				<td>
					<cfif prc.canManage>
						<a href="/admin/slides/edit/#slide.getId()#"><strong>#encodeForHTML( slide.getLabel() )#</strong></a>
					<cfelse>
						<strong>#encodeForHTML( slide.getLabel() )#</strong>
					</cfif>
				</td>
				<td class="muted">#encodeForHTML( slide.getHAlign() )# / #encodeForHTML( slide.getVAlign() )#</td>
				<td class="c">
					<cfif prc.canManage>
						<form class="inline" method="post" action="/admin/slides/#slide.getIsPublished() ? 'unpublish' : 'publish'#/#slide.getId()#">
							<input type="hidden" name="csrfToken" value="#encodeForHTMLAttribute( prc.csrfToken )#">
							<button type="submit" class="pill #slide.getIsPublished() ? 'on' : 'off'#"
							        title="#slide.getIsPublished() ? 'Unpublish' : 'Publish'#">#slide.getIsPublished() ? "Published" : "Draft"#</button>
						</form>
					<cfelse>
						<span class="pill #slide.getIsPublished() ? 'on' : 'off'#">#slide.getIsPublished() ? "Published" : "Draft"#</span>
					</cfif>
				</td>
				<td class="r nowrap">
					<cfif prc.canManage>
						<a class="ico" href="/admin/slides/edit/#slide.getId()#" title="Edit">Edit</a>
						<form class="inline" method="post" action="/admin/slides/remove/#slide.getId()#"
						      onsubmit="return confirm('Delete this slide?')">
							<input type="hidden" name="csrfToken" value="#encodeForHTMLAttribute( prc.csrfToken )#">
							<button type="submit" class="ico danger" title="Delete">Delete</button>
						</form>
					</cfif>
				</td>
			</tr>
		</cfloop>
	</tbody>
</table>
</cfoutput>
