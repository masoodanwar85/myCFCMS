<cfoutput>
<!---
	Rich text editing for admin content forms.

	Self-hosted rather than loaded from a CDN: the admin should work on a
	machine with no outbound internet, and a CDN outage should not take away a
	client's ability to edit their site.

	Included only when a handler sets `prc.useEditor`, because the build is
	~1.8MB and the dashboard, users and roles screens have nothing to edit.

	Any textarea carrying `data-editor` is upgraded. If the script fails to
	load, the plain textarea is still there and still submits — editing degrades
	rather than breaking.

	Images upload straight into the site's media library. The endpoint returns
	the URL CKEditor then writes into the content, so an image an author drops
	into a page is an ordinary media item afterwards — visible in the library,
	editable, deletable.

	The toolbar carries two image buttons, because they answer different
	questions:

	  * "Upload image"   — a file on this machine, not yet in the library.
	  * "Media library"  — something already uploaded, chosen from a grid.

	Without the second, re-using one photograph across ten pages meant
	uploading it ten times, leaving ten copies on disk. The picker reads
	`/admin/media/browse`, which is tenant-scoped and behind `media.view`, so
	it can only ever show the current site's images.
--->
<link rel="stylesheet" href="/includes/vendor/ckeditor5/ckeditor5.css">
<script src="/includes/vendor/ckeditor5/ckeditor5.umd.js"></script>
<script>
(function () {
	var targets = document.querySelectorAll( "textarea[data-editor]" );

	if ( !targets.length || typeof CKEDITOR === "undefined" ) {
		return;
	}

	var C = CKEDITOR;

	/**
	 * The picker dialog. Plain DOM rather than a CKEditor view, so it is styled
	 * by the admin stylesheet like every other list in the admin and does not
	 * have to be kept in step with the editor's own UI API.
	 *
	 * Resolves with the chosen item, or with null if the author backs out.
	 */
	function pickFromLibrary() {
		return new Promise( function ( resolve ) {
			var page = 1;

			var overlay = document.createElement( "div" );
			overlay.className = "picker-overlay";
			overlay.innerHTML =
				'<div class="picker" role="dialog" aria-modal="true" aria-label="Media library">' +
					'<div class="picker-head">' +
						'<strong>Media library</strong>' +
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
				fetch( "/admin/media/browse?page=" + page, {
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

						var img = document.createElement( "img" );
						img.src = item.url;
						// Decorative in the picker: the filename beneath it is
						// the label, so announcing the alt text as well would
						// read the same image twice.
						img.alt = "";
						img.loading = "lazy";

						var name = document.createElement( "span" );
						name.textContent = item.filename;

						var meta = document.createElement( "span" );
						meta.className = "muted";
						meta.textContent = item.altText
							? item.altText
							: "No alt text";

						cell.appendChild( img );
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

	/**
	 * Puts a "Media library" button on the toolbar. Inserting goes through the
	 * editor's own `insertImage` command, so the result is an ordinary image
	 * widget — resizable, captionable, styleable like any other.
	 */
	class MediaLibrary extends C.Plugin {
		static get pluginName() {
			return "MediaLibrary";
		}

		init() {
			var editor = this.editor;

			editor.ui.componentFactory.add( "mediaLibrary", function ( locale ) {
				var button = new C.ButtonView( locale );

				button.set( {
					label: "Media library",
					icon: C.IconImage,
					tooltip: true
				} );

				// Greyed out wherever an image cannot go — inside a caption,
				// for instance — rather than failing after the author has
				// already chosen a file.
				var command = editor.commands.get( "insertImage" );

				if ( command ) {
					button.bind( "isEnabled" ).to( command, "isEnabled" );
				}

				button.on( "execute", function () {
					pickFromLibrary().then( function ( item ) {
						if ( !item ) {
							return;
						}

						editor.execute( "insertImage", {
							source: { src: item.url, alt: item.altText || "" }
						} );
						editor.editing.view.focus();
					} );
				} );

				return button;
			} );
		}
	}

	// The session's CSRF token, so the upload is refused if it did not come
	// from a page this session was served.
	var token = document.querySelector( "input[name=csrfToken]" );

	targets.forEach( function ( el ) {
		C.ClassicEditor.create( el, {
			// CKEditor 5 is dual-licensed GPL2+/commercial. "GPL" selects the
			// open-source terms; a commercial deployment needs a real key.
			licenseKey: "GPL",
			plugins: [
				C.Essentials, C.Paragraph, C.Heading, C.Autoformat,
				C.Bold, C.Italic, C.Underline, C.Strikethrough,
				C.Link, C.List, C.BlockQuote, C.HorizontalLine,
				C.Table, C.TableToolbar, C.PasteFromOffice, C.SourceEditing,
				C.Image, C.ImageToolbar, C.ImageCaption, C.ImageStyle,
				C.ImageResize, C.ImageUpload, C.SimpleUploadAdapter,
				MediaLibrary
			],
			toolbar: [
				"undo", "redo", "|",
				"heading", "|",
				"bold", "italic", "underline", "strikethrough", "|",
				"link", "bulletedList", "numberedList", "blockQuote", "|",
				"uploadImage", "mediaLibrary", "insertTable", "horizontalLine", "|",
				"sourceEditing"
			],
			image: {
				toolbar: [
					"imageTextAlternative", "|",
					"imageStyle:inline", "imageStyle:block", "imageStyle:side"
				]
			},
			simpleUpload: {
				uploadUrl: "/admin/media/inline",
				withCredentials: true,
				headers: token ? { "X-CSRF-Token": token.value } : {}
			},
			heading: {
				options: [
					{ model: "paragraph", title: "Paragraph", class: "ck-heading_paragraph" },
					{ model: "heading2", view: "h2", title: "Heading", class: "ck-heading_heading2" },
					{ model: "heading3", view: "h3", title: "Subheading", class: "ck-heading_heading3" }
				]
			},
			table: { contentToolbar: [ "tableColumn", "tableRow", "mergeTableCells" ] }
		} ).then( function ( editor ) {
			// Write the editor's content back into the textarea before the form
			// is posted. ClassicEditor usually does this itself; doing it
			// explicitly means a submit triggered by script cannot miss it.
			var form = el.closest( "form" );

			if ( form ) {
				form.addEventListener( "submit", function () {
					editor.updateSourceElement();
				} );
			}
		} ).catch( function ( error ) {
			// Leave the textarea usable rather than blocking the edit.
			window.console && console.error( "Rich text editor failed to load:", error );
		} );
	} );
})();
</script>
</cfoutput>
