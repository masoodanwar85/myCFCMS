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
					Images: #encodeForHTML( arrayToList( prc.allowedImages, ", " ) )# &middot; up to #prc.maxImageMB#MB<br>
					Documents: #encodeForHTML( arrayToList( prc.allowedDocs, ", " ) )# &middot; up to #prc.maxDocumentMB#MB
				</p>
			</div>
			<div>
				<label for="altText">Alt text</label>
				<input type="text" id="altText" name="altText" placeholder="What the image shows">
				<p class="muted" style="font-size:.8rem">For images. Leave blank for decorative ones.</p>

				<label for="title">Title</label>
				<input type="text" id="title" name="title" placeholder="Terms of engagement">
				<p class="muted" style="font-size:.8rem">
					For documents: what a <code>[file]</code> link says when no label is given.
				</p>
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
				<a class="media-file" href="#xmlFormat( item.getUrl() )#" target="_blank" rel="noopener"
				   title="#encodeForHTMLAttribute( item.getTypeLabel() )#">
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
				<!--- A document's useful thing to copy is the shortcode, not
				      the URL: pasting the URL into a page makes a link that
				      breaks the day the file is replaced. --->
				<cfif item.isDocument()>
					<code style="font-size:.7rem">[file id="#item.getId()#"]</code>
				<cfelse>
					<code style="font-size:.7rem">#encodeForHTML( item.getUrl() )#</code>
				</cfif>
			</div>

			<cfif prc.canUpdate>
				<form id="alt-#item.getId()#" method="post" action="/admin/media/update/#item.getId()#">
					<input type="hidden" name="csrfToken" value="#encodeForHTMLAttribute( prc.csrfToken )#">
					<!--- Each kind gets the field that means something for it.
					      Alt text on a PDF describes a picture that is not
					      there; a title on a photograph is not what any screen
					      reads out. --->
					<cfif item.isDocument()>
						<input type="text" name="title" placeholder="Title, e.g. Terms of engagement"
						       value="#xmlFormat( item.getTitle() ?: '' )#">
					<cfelse>
						<input type="text" name="altText" placeholder="Alt text"
						       value="#xmlFormat( item.getAltText() ?: '' )#">
					</cfif>
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
