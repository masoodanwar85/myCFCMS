<cfoutput>
<h1>Pages</h1>
<p class="sub">The content tree for #encodeForHTML( prc.currentSite.getName() )#.</p>

<div class="adm-toolbar">
	<cfif prc.canCreate><a class="btn" href="/admin/pages/new">+ New page</a></cfif>
	<a class="btn secondary" href="/" target="_blank" rel="noopener">View site &nearr;</a>
	<span class="adm-count">#prc.tree.len()# pages</span>
</div>

<!---
	`data-page-tree` is what the script at the foot of this file looks for. The
	rows are rendered expanded and collapsed by that script on load, so a browser
	with no JavaScript shows the whole tree rather than a list of top-level pages
	with no way to reach the rest.
--->
<table data-page-tree>
	<thead><tr><th style="width:40%">Page</th><th>URL</th><th class="c">Status</th><th class="r">Actions</th></tr></thead>
	<tbody>
		<cfif !prc.tree.len()>
			<tr><td colspan="4" class="muted">No pages yet.</td></tr>
		</cfif>
		<cfloop array="#prc.tree#" index="row">
			<cfset p = row.page>
			<cfset isHome = !isNull( prc.homePage ) && prc.homePage.getId() eq p.getId()>
			<tr class="#p.isPublished() ? '' : 'is-off'#"
			    data-page-id="#p.getId()#"
			    data-parent="#row.parentId#">
				<td>
					<span class="indent" style="padding-left:#row.depth * 22#px"></span>

					<cfif row.childCount>
						<!---
							A button, not a link: it changes what is on screen and
							goes nowhere. `aria-expanded` is what tells a screen
							reader which state it is in, and the script keeps it
							in step with the caret.
						--->
						<button type="button" class="tree-toggle" aria-expanded="false"
						        aria-label="Show pages under #encodeForHTMLAttribute( p.getTitle() )#"
						        title="#row.childCount# sub-page#row.childCount eq 1 ? '' : 's'#"></button>
					<cfelse>
						<!--- Keeps titles aligned with those that do have a toggle. --->
						<span class="tree-leaf"></span>
					</cfif>

					<cfif prc.canUpdate>
						<a href="/admin/pages/edit/#p.getId()#"><strong>#encodeForHTML( p.getTitle() )#</strong></a>
					<cfelse>
						<strong>#encodeForHTML( p.getTitle() )#</strong>
					</cfif>
					<cfif isHome><span class="tag">home</span></cfif>
					<cfif p.isArchived()><span class="tag alt">archived</span></cfif>
					<cfif row.childCount><span class="muted tree-count">#row.childCount#</span></cfif>
				</td>
				<td class="mono"><a href="/#xmlFormat( p.getPath() )#" target="_blank" rel="noopener">/#encodeForHTML( p.getPath() )#</a></td>
				<td class="c">
					<!--- Status and the control that changes it are the same
					      thing, so it reads as one fact rather than two. --->
					<cfif prc.canPublish>
						<form class="inline" method="post" action="/admin/pages/#p.isPublished() ? 'unpublish' : 'publish'#/#p.getId()#">
							<input type="hidden" name="csrfToken" value="#encodeForHTMLAttribute( prc.csrfToken )#">
							<button type="submit" class="pill #p.isPublished() ? 'on' : 'off'#"
							        title="#p.isPublished() ? 'Unpublish this page' : 'Publish this page'#">#p.isPublished() ? "Published" : "Draft"#</button>
						</form>
					<cfelse>
						<span class="pill #p.isPublished() ? 'on' : 'off'#">#p.isPublished() ? "Published" : "Draft"#</span>
					</cfif>
				</td>
				<td class="r nowrap">
					<cfif prc.canUpdate><a class="ico" href="/admin/pages/edit/#p.getId()#" title="Edit">Edit</a></cfif>

					<cfif prc.canUpdate && !isHome && p.isPublished()>
						<form class="inline" method="post" action="/admin/pages/setHome/#p.getId()#">
							<input type="hidden" name="csrfToken" value="#encodeForHTMLAttribute( prc.csrfToken )#">
							<button type="submit" class="ico" title="Serve this page at the site root">Set home</button>
						</form>
					</cfif>

					<cfif prc.canDelete>
						<form class="inline" method="post" action="/admin/pages/remove/#p.getId()#"
						      onsubmit="return confirm('Delete #encodeForJavaScript( p.getTitle() )#?')">
							<input type="hidden" name="csrfToken" value="#encodeForHTMLAttribute( prc.csrfToken )#">
							<button type="submit" class="ico danger" title="Delete">Delete</button>
						</form>
					</cfif>
				</td>
			</tr>
		</cfloop>
	</tbody>
</table>
<script>
/*
	Folding the page tree.

	The table is flat — columns have to line up across every level, so the tree
	cannot be nested markup — and each row carries `data-page-id` and
	`data-parent` instead. This turns that into a fold.

	Collapsing happens HERE rather than in the rendered HTML or in CSS, on
	purpose: with no JavaScript the whole tree is already on the page and every
	page is reachable. Hiding rows in the markup would make a browser without
	this script show only top-level pages with no way to reach the rest.
*/
( function () {
	var table = document.querySelector( "[data-page-tree]" );

	if ( !table ) {
		return;
	}

	var rows       = Array.prototype.slice.call( table.querySelectorAll( "tr[data-page-id]" ) );
	var childrenOf = {};

	rows.forEach( function ( row ) {
		var parent = row.getAttribute( "data-parent" );

		( childrenOf[ parent ] = childrenOf[ parent ] || [] ).push( row );
	} );

	function toggleOf( row ) {
		return row.querySelector( ".tree-toggle" );
	}

	function setRowOpen( row, open ) {
		var toggle = toggleOf( row );

		if ( !toggle ) {
			return;
		}

		toggle.setAttribute( "aria-expanded", open ? "true" : "false" );
		toggle.setAttribute(
			"aria-label",
			( open ? "Hide" : "Show" ) + " pages under " + row.querySelector( "strong" ).textContent.trim()
		);
	}

	function show( id ) {
		( childrenOf[ id ] || [] ).forEach( function ( row ) {
			row.classList.remove( "is-folded" );
		} );
	}

	/*
		Hides the whole branch, not just the immediate children, and marks each
		one closed on the way down. Without the recursion, collapsing a
		grandparent and reopening it would reveal descendants that were open
		when it was closed — the fold would remember state the caret denies.
	*/
	function hide( id ) {
		( childrenOf[ id ] || [] ).forEach( function ( row ) {
			row.classList.add( "is-folded" );
			setRowOpen( row, false );
			hide( row.getAttribute( "data-page-id" ) );
		} );
	}

	function collapseAll() {
		rows.forEach( function ( row ) {
			if ( row.getAttribute( "data-parent" ) !== "0" ) {
				row.classList.add( "is-folded" );
			}

			setRowOpen( row, false );
		} );
	}

	function expandAll() {
		rows.forEach( function ( row ) {
			row.classList.remove( "is-folded" );
			setRowOpen( row, true );
		} );
	}

	table.addEventListener( "click", function ( event ) {
		var toggle = event.target.closest( ".tree-toggle" );

		if ( !toggle ) {
			return;
		}

		var row  = toggle.closest( "tr" );
		var id   = row.getAttribute( "data-page-id" );
		var open = toggle.getAttribute( "aria-expanded" ) === "true";

		if ( open ) {
			hide( id );
		} else {
			show( id );
		}

		setRowOpen( row, !open );
	} );

	/*
		Built here rather than rendered in the markup, so it never appears for a
		browser that could not act on it. On a site four levels deep, reaching a
		page with everything folded is a lot of clicks; this is the way out.
	*/
	var hasBranches = rows.some( function ( row ) { return toggleOf( row ); } );

	if ( hasBranches ) {
		var toolbar = document.querySelector( ".adm-toolbar" );
		var button  = document.createElement( "button" );

		button.type      = "button";
		button.className = "btn secondary";
		button.textContent = "Expand all";

		button.addEventListener( "click", function () {
			var expanding = button.textContent === "Expand all";

			if ( expanding ) {
				expandAll();
			} else {
				collapseAll();
			}

			button.textContent = expanding ? "Collapse all" : "Expand all";
		} );

		if ( toolbar ) {
			toolbar.insertBefore( button, toolbar.querySelector( ".adm-count" ) );
		}
	}

	collapseAll();
} )();
</script>
</cfoutput>