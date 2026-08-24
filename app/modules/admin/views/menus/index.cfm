<cfoutput>
<h1>Menus</h1>
<p class="sub">
	The navigation for #encodeForHTML( prc.currentSite.getName() )#.
</p>

<cfif !prc.usingCurated>
	<p class="flash">
		This site is using its <strong>automatic navigation</strong> &mdash; the site's top-level
		pages, plus a link from each module that offers one. Build a menu called
		<code>primary</code> to take over, or leave this as it is.
	</p>
</cfif>

<div class="adm-toolbar">
	<a class="btn secondary" href="/" target="_blank" rel="noopener">View site &nearr;</a>
	<span class="adm-count">#prc.menus.len()# menu#prc.menus.len() eq 1 ? "" : "s"#</span>
</div>

<table>
	<thead><tr><th>Menu</th><th>Slug</th><th class="r">Actions</th></tr></thead>
	<tbody>
		<cfif !prc.menus.len()>
			<tr><td colspan="3" class="muted">No menus yet.</td></tr>
		</cfif>
		<cfloop array="#prc.menus#" index="menu">
			<tr>
				<td><a href="/admin/menus/edit/#menu.getId()#"><strong>#encodeForHTML( menu.getName() )#</strong></a></td>
				<td>
					<code>#encodeForHTML( menu.getSlug() )#</code>
					<cfif menu.getSlug() eq "primary"><span class="tag">header</span></cfif>
				</td>
				<td class="actions">
					<a class="ico" href="/admin/menus/edit/#menu.getId()#">Edit</a>
					<form class="inline" method="post" action="/admin/menus/remove/#menu.getId()#"
					      onsubmit="return confirm('Delete #encodeForJavaScript( menu.getName() )#? The site falls back to its automatic navigation.')">
						<input type="hidden" name="csrfToken" value="#encodeForHTMLAttribute( prc.csrfToken )#">
						<button type="submit" class="ico danger">Delete</button>
					</form>
				</td>
			</tr>
		</cfloop>
	</tbody>
</table>

<h2>Add a menu</h2>
<form class="narrow" method="post" action="/admin/menus/create">
	<input type="hidden" name="csrfToken" value="#encodeForHTMLAttribute( prc.csrfToken )#">

	<label for="name">Name</label>
	<input type="text" id="name" name="name" placeholder="Primary" required>

	<label for="slug">Slug</label>
	<input type="text" id="slug" name="slug" placeholder="primary">
	<p class="muted" style="font-size:.8rem">
		How the theme asks for this menu. <code>primary</code> is the one rendered in the header.
		Leave blank to derive it from the name.
	</p>

	<div class="actions-bar"><button type="submit">Add menu</button></div>
</form>
</cfoutput>
