<cfoutput>
<cfset editing = isObject( prc.slide )>
<h1>#editing ? "Edit slide" : "New slide"#</h1>
<p class="sub">One panel of the slider. Its image and overlay HTML move together. Publish two or more slides and they advance automatically.</p>

<form method="post" action="#editing ? '/admin/slides/update/' & prc.slide.getId() : '/admin/slides/create'#">
	<input type="hidden" name="csrfToken" value="#encodeForHTMLAttribute( prc.csrfToken )#">

	<label for="imageUrl">Background image</label>
	<div class="media-field">
		<input type="text" id="imageUrl" name="imageUrl"
		       value="#editing ? encodeForHTMLAttribute( prc.slide.getImageUrl() ?: '' ) : ''#"
		       placeholder="/media/2026/09/hero.jpg">
		<button type="button" class="ico" data-pick-media="imageUrl">Choose&hellip;</button>
		<button type="button" class="ico" data-clear-media="imageUrl">Clear</button>
	</div>
	<p class="muted" style="font-size:.8rem">Pick from the media library, or paste a <code>/media/&hellip;</code> path.</p>
	<cfif editing && len( prc.slide.getImageUrl() ?: "" )>
		<p><img src="#encodeForHTMLAttribute( prc.slide.getImageUrl() )#" alt="" style="max-height:8rem;max-width:100%;border-radius:8px"></p>
	</cfif>

	<label for="imageAlt">Image alt text</label>
	<input type="text" id="imageAlt" name="imageAlt" maxlength="255"
	       value="#editing ? encodeForHTMLAttribute( prc.slide.getImageAlt() ?: '' ) : ''#"
	       placeholder="Optional; for screen readers">

	<label for="overlayHtml">Overlay HTML</label>
	<textarea id="overlayHtml" name="overlayHtml" data-editor>#editing ? encodeForHTML( prc.slide.getOverlayHtml() ?: "" ) : ""#</textarea>
	<p class="muted" style="font-size:.8rem">
		Headings, copy and buttons. Use the theme's button classes, e.g.
		<code>&lt;a class="btn" href="/will"&gt;Start your Will&lt;/a&gt;</code>.
	</p>

	<div class="grid2">
		<div>
			<label for="hAlign">Horizontal</label>
			<select id="hAlign" name="hAlign">
				<cfloop list="left,center,right" index="option">
					<option value="#option#"
						<cfif ( editing ? prc.slide.getHAlign() : "left" ) eq option> selected</cfif>>#option#</option>
				</cfloop>
			</select>
		</div>
		<div>
			<label for="vAlign">Vertical</label>
			<select id="vAlign" name="vAlign">
				<cfloop list="top,middle,bottom" index="option">
					<option value="#option#"
						<cfif ( editing ? prc.slide.getVAlign() : "middle" ) eq option> selected</cfif>>#option#</option>
				</cfloop>
			</select>
		</div>
	</div>

	<div class="grid2">
		<div>
			<label for="sortOrder">Sort order</label>
			<input type="number" id="sortOrder" name="sortOrder"
			       value="#editing ? encodeForHTMLAttribute( prc.slide.getSortOrder() ) : '0'#">
			<p class="muted" style="font-size:.8rem">Leave at 0 on a new slide to append it.</p>
		</div>
		<div>
			<label>&nbsp;</label>
			<div class="checks">
				<label>
					<input type="checkbox" name="isPublished"<cfif editing && prc.slide.getIsPublished()> checked</cfif>>
					Published (this panel joins the moving slider)
				</label>
			</div>
		</div>
	</div>

	<div class="actions-bar">
		<button type="submit">#editing ? "Save slide" : "Create slide"#</button>
		<a class="btn secondary" href="/admin/slides">Cancel</a>
	</div>
</form>

<script>
document.addEventListener( "click", function ( e ) {
	var pick = e.target.closest( "[data-pick-media]" );

	if ( pick && window.cmsPickMedia ) {
		window.cmsPickMedia().then( function ( item ) {
			if ( !item ) {
				return;
			}

			var field = document.getElementById( pick.getAttribute( "data-pick-media" ) );
			if ( field ) {
				field.value = item.url;
			}

			var alt = document.getElementById( "imageAlt" );
			if ( alt && item.altText && !alt.value ) {
				alt.value = item.altText;
			}
		} );

		return;
	}

	var clear = e.target.closest( "[data-clear-media]" );

	if ( clear ) {
		var target = document.getElementById( clear.getAttribute( "data-clear-media" ) );
		if ( target ) {
			target.value = "";
		}
	}
} );
</script>
</cfoutput>
