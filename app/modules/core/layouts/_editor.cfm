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
	uploading it ten times, leaving ten copies on disk.

	The picker dialog itself lives in `_picker.cfm` and is loaded on every admin
	screen, because Settings needs it too for the site logo. This file only adds
	the toolbar button that calls it.
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
					window.cmsPickMedia().then( function ( item ) {
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
			// The dropdown used to start at h2, on the reasoning that the
			// theme already printed the page title as the h1 and a second one
			// would be wrong. That held until pages gained `show_heading`:
			// an author who turns the theme's heading off has to be able to
			// write their own, and there was no way to do it — the sanitiser
			// allowed h1 all along, the toolbar simply never offered it.
			//
			// "Page heading" rather than "Heading 1", because the choice being
			// made is which of these is the page's one top-level heading, not
			// which font size to apply.
			heading: {
				options: [
					{ model: "paragraph", title: "Paragraph", class: "ck-heading_paragraph" },
					{ model: "heading1", view: "h1", title: "Page heading", class: "ck-heading_heading1" },
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
