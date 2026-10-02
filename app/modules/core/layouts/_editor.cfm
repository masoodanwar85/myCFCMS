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

	A third button, "Insert file", links a document instead of showing an image.
	It writes a `[file id="12"]` shortcode rather than an `<a href>`: the label,
	type and size are then read from the library when the page renders, so
	replacing a PDF next year corrects every page that links it instead of
	leaving a hunt through content. See `FileShortcode.cfc`.

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

	/**
	 * The text inside the current selection, if any.
	 *
	 * Used as the link's label, so selecting "our terms of engagement" and
	 * pressing the button produces a link reading that — rather than making the
	 * author retype it, or silently discarding what they had selected.
	 */
	function selectedText( editor ) {
		var range = editor.model.document.selection.getFirstRange();

		if ( !range ) {
			return "";
		}

		var text = "";

		Array.from( range.getItems() ).forEach( function ( item ) {
			if ( item.is( "$text" ) || item.is( "$textProxy" ) ) {
				text += item.data;
			}
		} );

		return text.trim();
	}

	/**
	 * Puts an "Insert file" button on the toolbar, for linking a document.
	 *
	 * Writes a `[file]` shortcode as plain text rather than building a link
	 * widget. The shortcode is what makes the link a reference to a library
	 * item instead of a copy of today's filename, and the editor has no
	 * shortcode preview, so the author sees the code — the same as `[image]`.
	 */
	class FileLibrary extends C.Plugin {
		static get pluginName() {
			return "FileLibrary";
		}

		init() {
			var editor = this.editor;

			editor.ui.componentFactory.add( "insertFile", function ( locale ) {
				var button = new C.ButtonView( locale );

				button.set( {
					label: "Insert file",
					// Whichever of these the bundle exports; the label carries
					// the meaning either way.
					icon: C.IconBrowseFiles || C.IconLink || C.IconImage,
					tooltip: true
				} );

				button.on( "execute", function () {
					window.cmsPickMedia( { kind: "document" } ).then( function ( item ) {
						if ( !item ) {
							return;
						}

						var label = selectedText( editor );
						var code  = label
							? "[file id=\"" + item.id + "\"]" + label + "[/file]"
							: "[file id=\"" + item.id + "\"]";

						editor.model.change( function ( writer ) {
							// Replaces the selection when there is one, which is
							// what makes the label round-trip.
							editor.model.insertContent( writer.createText( code ) );
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
				C.GeneralHtmlSupport,
				C.Image, C.ImageToolbar, C.ImageCaption, C.ImageStyle,
				C.ImageResize, C.ImageUpload, C.SimpleUploadAdapter,
				MediaLibrary, FileLibrary
			],
			toolbar: [
				"undo", "redo", "|",
				"heading", "|",
				"bold", "italic", "underline", "strikethrough", "|",
				"link", "bulletedList", "numberedList", "blockQuote", "|",
				"uploadImage", "mediaLibrary", "insertFile", "insertTable", "horizontalLine", "|",
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
			table: { contentToolbar: [ "tableColumn", "tableRow", "mergeTableCells" ] },

			// Elements and attributes CKEditor has no plugin for, and therefore
			// discards. CKEditor 5 keeps a schema of what it understands and
			// drops anything outside it — silently, and on load as well as on
			// paste. A `<div>` or `<button class="btn">` typed in Source view
			// survived until the editor next read the content back, then
			// vanished. Same for `class` on an `<a>`: the Link plugin stores
			// href, not class, so a theme button (`<a class="btn">`) was wiped
			// on the next open. That looked like the sanitiser eating it.
			//
			// The lists mirror `antisamy-cms.xml`, and the rule for keeping them
			// in step is one-directional: the editor may allow *less* than the
			// sanitiser, never more. Letting the editor keep an attribute the
			// sanitiser then strips is worse than not keeping it at all — the
			// author sees it work, saves, and finds it gone.
			htmlSupport: {
				allow: [
					/*
						`class` on every tag the sanitiser will keep it on.

						`class` is in `<global-tag-attributes>` in
						`antisamy-cms.xml`, so the server already accepts it on
						anything. This is the editor catching up: it used to
						grant classes to `div`, `span`, `a` and `button` only,
						so `<h2 class="lead">` or `<td class="num">` typed in
						Source view vanished the next time the editor read the
						content back.

						Spelled out rather than a match-anything name pattern on
						purpose — and note that writing one in a comment here
						would end the comment early, since it contains the
						closing delimiter. A match-everything rule also enables
						elements CKEditor
						has no feature for, including ones AntiSamy removes
						(`<form>`, `<input>`, `<svg>`) — so the author would see
						them survive in the editor and disappear on save, which
						is the failure this whole block exists to avoid. Every
						tag below is one the policy validates.

						`br`, `col` and `hr` are deliberately absent: the policy
						marks them `truncate`, which keeps the tag and drops
						every attribute on it, so a class there would be lost.
					*/
					{
						name: /^(a|abbr|article|b|blockquote|button|caption|cite|code|colgroup|dd|del|div|dl|dt|em|figcaption|figure|h[1-6]|i|img|ins|kbd|li|mark|ol|p|pre|q|s|samp|section|small|span|strike|strong|sub|sup|table|tbody|td|tfoot|th|thead|tr|tt|u|ul|var)$/,
						classes: true
					},

					/*
						Attributes beyond `class`, which are genuinely per-tag.
						These also enable `div`, `span` and `button` as
						elements, since CKEditor has no feature that produces
						them.

						`id` and `style` stay absent because they are absent
						from the policy's global list — `style` is granted only
						to the few tags that name it.
					*/
					{
						name: /^(div|span)$/,
						attributes: [ "lang", "title", "dir" ]
					},
					{
						name: "a",
						attributes: [ "href", "rel", "target", "lang", "title", "dir" ]
					},
					{
						name: "button",
						attributes: [ "type", "disabled", "lang", "title", "dir" ]
					}
				]
			}
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
