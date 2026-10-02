<cfoutput>
<!---
	The media library picker, as a standalone dialog.

	Extracted from the editor because two screens now need it: CKEditor's
	"Media library" toolbar button, and the logo field in Settings. It was
	previously nested inside the editor's IIFE, which meant a screen without a
	rich-text field could not reach it — and Settings has no textarea at all.

	Exposes one function:

	    window.cmsPickMedia().then( function ( item ) { ... } )
	    window.cmsPickMedia( { kind: "document" } ).then( ... )

	resolving with the chosen media item, or with `null` if the author backs
	out. The item is whatever `/admin/media/browse` returned — `url`, `filename`
	and `altText` are the fields callers use, plus `label`, `typeLabel` and
	`humanSize` for a document.

	`kind` defaults to `"image"`, which is what every caller written before
	documents existed is for: the CKEditor image button, the logo field, the
	featured image field, the slide background. A default of "everything" would
	start offering those a PDF.

	Loaded on every admin screen. It is a few kilobytes and defines one
	function; gating it behind a flag would mean every future consumer having to
	remember to set that flag.

	Styling comes from the admin stylesheet (`.picker-*`), so the dialog matches
	the rest of the admin rather than carrying its own look.
--->
<script>
(function () {
/**
 * The picker dialog. Plain DOM rather than a CKEditor view, so it is styled
 * by the admin stylesheet like every other list in the admin and does not
 * have to be kept in step with the editor's own UI API.
 *
 * Resolves with the chosen item, or with null if the author backs out.
 */
function pickFromLibrary( options ) {
	return new Promise( function ( resolve ) {
		var page = 1;
		var kind = ( options && options.kind ) === "document" ? "document" : "image";
		var what = kind === "document" ? "Documents" : "Images";

		var overlay = document.createElement( "div" );
		overlay.className = "picker-overlay";
		overlay.innerHTML =
			'<div class="picker" role="dialog" aria-modal="true" aria-label="Media library">' +
				'<div class="picker-head">' +
					'<strong>Media library &mdash; ' + what + '</strong>' +
					'<button type="button" class="ico picker-close">Close</button>' +
				'</div>' +
				'<div class="picker-body"><p class="muted">Loading&hellip;</p></div>' +
				'<div class="picker-foot"></div>' +
			'</div>';

		var body = overlay.querySelector( ".picker-body" );
		var foot = overlay.querySelector( ".picker-foot" );

		function close( item ) {
			document.removeEventListener( "keydown", onKey );
			overlay.remove();
			resolve( item || null );
		}

		function onKey( e ) {
			if ( e.key === "Escape" ) {
				close( null );
			}
		}

		function load() {
			body.innerHTML = '<p class="muted">Loading&hellip;</p>';
			foot.innerHTML = "";

			// Same origin, so the session cookie rides along; `credentials`
			// is explicit because a refused request must look like a
			// refusal and not like an empty library.
			fetch( "/admin/media/browse?kind=" + kind + "&page=" + page, {
				credentials: "same-origin",
				headers: { "Accept": "application/json" }
			} )
				.then( function ( r ) {
					if ( !r.ok ) {
						throw new Error( "The media library could not be read (" + r.status + ")." );
					}

					// A lapsed session redirects to the sign-in page, which
					// `fetch` follows and reports as a perfectly good 200 of
					// HTML. Without this check the author would be shown a
					// JSON parse error instead of being told to sign in.
					var type = r.headers.get( "content-type" ) || "";

					if ( type.indexOf( "json" ) === -1 ) {
						throw new Error( "Your session has expired. Copy your work, reload the page and sign in again." );
					}

					return r.json();
				} )
				.then( render )
				.catch( function ( err ) {
					body.innerHTML = "";
					var p = document.createElement( "p" );
					p.className = "flash error";
					p.textContent = err.message;
					body.appendChild( p );
				} );
		}

		function render( data ) {
			body.innerHTML = "";

			if ( !data.items.length ) {
				var empty = document.createElement( "p" );
				empty.className = "muted";
				empty.textContent = page > 1
					? "Nothing on this page."
					: kind === "document"
						? "No documents in the library yet. Upload one from the Media screen."
						: "No images in the library yet. Upload one from the Media screen, or use the upload button in the toolbar.";
				body.appendChild( empty );
			} else {
				var grid = document.createElement( "div" );
				grid.className = "picker-grid";

				data.items.forEach( function ( item ) {
					var cell = document.createElement( "button" );
					cell.type = "button";
					cell.className = "picker-item";
					cell.title = item.filename;

					if ( item.kind === "document" ) {
						// No thumbnail to show, so the extension stands in for
						// one — it is what tells a reader at a glance whether
						// they are about to link a PDF or a spreadsheet.
						cell.classList.add( "is-document" );

						var badge = document.createElement( "span" );
						badge.className = "picker-ext";
						badge.textContent = item.typeLabel;

						cell.appendChild( badge );
					} else {
						var img = document.createElement( "img" );
						img.src = item.url;
						// Decorative in the picker: the filename beneath it is
						// the label, so announcing the alt text as well would
						// read the same image twice.
						img.alt = "";
						img.loading = "lazy";

						cell.appendChild( img );
					}

					var name = document.createElement( "span" );
					name.textContent = item.filename;

					var meta = document.createElement( "span" );
					meta.className = "muted";

					// A document's useful second line is its size — what the
					// reader will spend. An image's is its alt text, which is
					// the thing most likely to be missing and worth fixing.
					if ( item.kind === "document" ) {
						meta.textContent = item.humanSize;
					} else {
						meta.textContent = item.altText ? item.altText : "No alt text";
					}

					cell.appendChild( name );
					cell.appendChild( meta );
					cell.addEventListener( "click", function () {
						close( item );
					} );

					grid.appendChild( cell );
				} );

				body.appendChild( grid );
			}

			if ( data.totalPages > 1 ) {
				var prev = document.createElement( "button" );
				prev.type = "button";
				prev.className = "ico";
				prev.textContent = "\u2190 Previous";
				prev.disabled = page <= 1;
				prev.addEventListener( "click", function () { page--; load(); } );

				var where = document.createElement( "span" );
				where.className = "muted";
				where.textContent = "Page " + data.page + " of " + data.totalPages;

				var next = document.createElement( "button" );
				next.type = "button";
				next.className = "ico";
				next.textContent = "Next \u2192";
				next.disabled = page >= data.totalPages;
				next.addEventListener( "click", function () { page++; load(); } );

				foot.appendChild( prev );
				foot.appendChild( where );
				foot.appendChild( next );
			}
		}

		overlay.querySelector( ".picker-close" ).addEventListener( "click", function () {
			close( null );
		} );

		// A click on the backdrop, but not one that started inside the panel.
		overlay.addEventListener( "mousedown", function ( e ) {
			if ( e.target === overlay ) {
				close( null );
			}
		} );

		document.addEventListener( "keydown", onKey );
		document.body.appendChild( overlay );
		load();
	} );
}

	window.cmsPickMedia = pickFromLibrary;

	/*
		Media fields, anywhere in the admin.

		Delegated over `data-pick-media` / `data-clear-media` rather than bound
		to one field, so a new media field is markup and no JavaScript:

		    <input type="text" id="heroUrl" name="heroUrl">
		    <button type="button" data-pick-media="heroUrl">Choose…</button>
		    <button type="button" data-clear-media="heroUrl">Clear</button>

		Add `data-pick-kind="document"` to browse documents instead of images.
		Omitted, it picks an image, because that is what every field using this
		before documents existed is for.

		This lived in the Settings view until a second screen needed it. Without
		the picker the text input still accepts a pasted URL, which is why the
		field is never read-only.
	*/
	document.addEventListener( "click", function ( event ) {
		var pick = event.target.closest( "[data-pick-media]" );

		if ( pick && window.cmsPickMedia ) {
			window.cmsPickMedia( { kind: pick.getAttribute( "data-pick-kind" ) } ).then( function ( item ) {
				if ( !item ) {
					return;
				}

				var field = document.getElementById( pick.getAttribute( "data-pick-media" ) );

				if ( field ) {
					field.value = item.url;
					// So anything watching the field — a preview, a dirty-form
					// guard — hears about a value it did not see typed.
					field.dispatchEvent( new Event( "change", { bubbles: true } ) );
				}
			} );

			return;
		}

		var clear = event.target.closest( "[data-clear-media]" );

		if ( clear ) {
			var target = document.getElementById( clear.getAttribute( "data-clear-media" ) );

			if ( target ) {
				target.value = "";
				target.dispatchEvent( new Event( "change", { bubbles: true } ) );
			}
		}
	} );
})();
</script>
</cfoutput>
