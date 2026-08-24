<cfoutput>
<h1>Media</h1>
<p class="sub">
	Files uploaded to #encodeForHTML( prc.currentSite.getName() )#.
	<span class="muted">#prc.usedMB#MB used.</span>
</p>

<cfif prc.canUpload>
	<form method="post" action="/admin/media/upload" enctype="multipart/form-data">
		<input type="hidden" name="csrfToken" value="#encodeForHTMLAttribute( prc.csrfToken )#">
		<div class="grid2">
			<div>
				<label for="file">Add a file</label>
				<input type="file" id="file" name="file" required
				       accept="#encodeForHTMLAttribute( '.' & arrayToList( prc.allowed, ',.' ) )#">
				<p class="muted" style="font-size:.8rem">
					#encodeForHTML( arrayToList( prc.allowed, ", " ) )# &middot; up to #prc.maxMB#MB
				</p>
			</div>
			<div>
				<label for="altText">Alt text</label>
				<input type="text" id="altText" name="altText" placeholder="What the image shows">
				<p class="muted" style="font-size:.8rem">Leave blank for decorative images.</p>
			</div>
		</div>
		<div class="actions-bar"><button type="submit">Upload</button></div>
	</form>
</cfif>

<cfif !prc.items.len()>
	<p class="muted">Nothing uploaded yet.</p>
</cfif>

<div class="media-grid">
	<cfloop array="#prc.items#" index="item">
		<div class="media-card">
			<cfif item.isImage()>
				<a href="#xmlFormat( item.getUrl() )#" target="_blank" rel="noopener">
					<img src="#xmlFormat( item.getUrl() )#" alt="#xmlFormat( item.getEffectiveAlt() )#" loading="lazy">
				</a>
			<cfelse>
				<a class="media-file" href="#xmlFormat( item.getUrl() )#" target="_blank" rel="noopener">
					#encodeForHTML( uCase( item.getExtension() ) )#
				</a>
			</cfif>

			<div class="media-meta">
				<div title="#encodeForHTMLAttribute( item.getOriginalFilename() )#">
					#encodeForHTML( item.getOriginalFilename() )#
				</div>
				<div class="muted">
					#encodeForHTML( item.getHumanSize() )#<cfif !isNull( item.getWidth() )> &middot; #item.getWidth()#&times;#item.getHeight()#</cfif>
				</div>
				<code style="font-size:.7rem">#encodeForHTML( item.getUrl() )#</code>
			</div>

			<cfif prc.canUpdate>
				<form id="alt-#item.getId()#" method="post" action="/admin/media/update/#item.getId()#">
					<input type="hidden" name="csrfToken" value="#encodeForHTMLAttribute( prc.csrfToken )#">
					<input type="text" name="altText" placeholder="Alt text"
					       value="#xmlFormat( item.getAltText() ?: '' )#">
				</form>
			</cfif>

			<div class="media-actions">
				<cfif prc.canUpdate>
					<!--- Outside the form element so it can share a row with Delete;
					      `form=` still submits it as part of the alt-text form. --->
					<button type="submit" class="ico" form="alt-#item.getId()#">Save</button>
				</cfif>
				<cfif prc.canDelete>
					<form class="inline" method="post" action="/admin/media/remove/#item.getId()#"
					      onsubmit="return confirm('Delete this file? Anything still using it will show a broken image.')">
						<input type="hidden" name="csrfToken" value="#encodeForHTMLAttribute( prc.csrfToken )#">
						<button type="submit" class="ico danger">Delete</button>
					</form>
				</cfif>
			</div>
		</div>
	</cfloop>
</div>

<cfinclude template="/core/views/_pagination.cfm">
</cfoutput>
