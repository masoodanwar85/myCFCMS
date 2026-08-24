<cfoutput>
<h1>#encodeForHTML( prc.menu.getName() )#</h1>
<p class="sub">
	Menu <code>#encodeForHTML( prc.menu.getSlug() )#</code> &middot;
	<a href="/admin/menus">all menus</a>
</p>

<div class="adm-toolbar">
	<form class="inline" method="post" action="/admin/menus/rename/#prc.menu.getId()#">
		<input type="hidden" name="csrfToken" value="#encodeForHTMLAttribute( prc.csrfToken )#">
		<input type="text" name="name" value="#encodeForHTMLAttribute( prc.menu.getName() )#"
		       aria-label="Menu name" style="width:14rem">
		<button type="submit" class="ico">Rename</button>
	</form>
	<span class="adm-count">#prc.items.len()# top-level item#prc.items.len() eq 1 ? "" : "s"#</span>
</div>

<table>
	<thead><tr><th>Item</th><th>Links to</th><th class="c">New tab</th><th class="r">Actions</th></tr></thead>
	<tbody>
		<cfif !prc.items.len()>
			<tr><td colspan="4" class="muted">Nothing in this menu yet.</td></tr>
		</cfif>

		<cfloop array="#prc.items#" index="item">
			<cfset rows = [ { "item" : item, "depth" : 0 } ]>
			<cfloop array="#item.getChildren()#" index="child">
				<cfset rows.append( { "item" : child, "depth" : 1 } )>
			</cfloop>

			<cfloop array="#rows#" index="row">
				<cfset node = row.item>
				<tr<cfif !node.getIsAvailable()> class="is-off"</cfif>>
					<td>
						<cfif row.depth><span class="muted">&mdash;&nbsp;</span></cfif>
						<strong>#encodeForHTML( node.getLabel() )#</strong>
					</td>
					<td>
						<cfif node.getIsAvailable()>
							<a href="#xmlFormat( node.getHref() )#" target="_blank" rel="noopener">#encodeForHTML( node.getHref() )#</a>
						<cfelse>
							<span class="tag">missing</span>
							<span class="muted">
								<!--- Named, not just flagged: an editor has to know *what* went
								      away to decide whether to relink it or drop the item. --->
								#encodeForHTML( node.getLinkDescription() )# no longer exists
							</span>
						</cfif>
					</td>
					<td class="c">
						<cfif len( node.getTarget() )><span class="pill on">new tab</span><cfelse><span class="muted">&mdash;</span></cfif>
					</td>
					<td class="actions">
						<cfloop list="up,down" index="direction">
							<form class="inline" method="post" action="/admin/menus/moveItem/#node.getId()#">
								<input type="hidden" name="csrfToken" value="#encodeForHTMLAttribute( prc.csrfToken )#">
								<input type="hidden" name="menuId" value="#prc.menu.getId()#">
								<input type="hidden" name="direction" value="#direction#">
								<button type="submit" class="ico" title="Move #direction#">#direction eq "up" ? "&uarr;" : "&darr;"#</button>
							</form>
						</cfloop>

						<form class="inline" method="post" action="/admin/menus/removeItem/#node.getId()#"
						      onsubmit="return confirm('Remove #encodeForJavaScript( node.getLabel() )# from this menu?')">
							<input type="hidden" name="csrfToken" value="#encodeForHTMLAttribute( prc.csrfToken )#">
							<input type="hidden" name="menuId" value="#prc.menu.getId()#">
							<button type="submit" class="ico danger">Remove</button>
						</form>
					</td>
				</tr>
			</cfloop>
		</cfloop>
	</tbody>
</table>

<h2>Add an item</h2>
<form method="post" action="/admin/menus/addItem/#prc.menu.getId()#">
	<input type="hidden" name="csrfToken" value="#encodeForHTMLAttribute( prc.csrfToken )#">

	<label for="label">Label</label>
	<input type="text" id="label" name="label" required placeholder="About us">

	<div class="grid2">
		<div>
			<label for="target">Links to</label>
			<select id="target" name="target">
				<option value="url">A web address</option>
				<cfset currentGroup = "">
				<cfloop array="#prc.targets#" index="option">
					<cfif option.group neq currentGroup>
						<cfif len( currentGroup )></optgroup></cfif>
						<optgroup label="#encodeForHTMLAttribute( option.group )#">
						<cfset currentGroup = option.group>
					</cfif>
					<option value="#xmlFormat( option.type & ':' & option.id )#">#encodeForHTML( option.label )#</option>
				</cfloop>
				<cfif len( currentGroup )></optgroup></cfif>
			</select>
			<p class="muted" style="font-size:.8rem">
				Linking to a page rather than typing its address means the menu follows it if
				it is ever renamed.
			</p>
		</div>

		<div>
			<label for="url">Web address</label>
			<input type="text" id="url" name="url" placeholder="https://example.com">
			<p class="muted" style="font-size:.8rem">
				Only used when <strong>a web address</strong> is selected. Must start with
				<code>http://</code>, <code>https://</code>, <code>mailto:</code>,
				<code>tel:</code>, <code>/</code> or <code>##</code>.
			</p>
		</div>
	</div>

	<div class="grid2">
		<div>
			<label for="parentId">Nest under</label>
			<select id="parentId" name="parentId">
				<option value="0">Nothing &mdash; top level</option>
				<cfloop array="#prc.parents#" index="parent">
					<option value="#parent.getId()#">#encodeForHTML( parent.getLabel() )#</option>
				</cfloop>
			</select>
		</div>
		<div>
			<div class="checks" style="margin-top:1.7rem">
				<label><input type="checkbox" name="newTab"> Open in a new tab</label>
			</div>
		</div>
	</div>

	<div class="actions-bar"><button type="submit">Add item</button></div>
</form>
</cfoutput>
