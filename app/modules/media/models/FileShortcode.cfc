/**
 * `[file id="12"]An optional label[/file]`
 *
 * A link to a document in the library — a PDF, a spreadsheet, a form to print.
 *
 * ## Why a reference and not a plain link
 *
 * An author could write `<a href="/media/2026/10/terms-a1b2c3d4.pdf">` and it
 * would work. The reason not to is what happens next year: the terms are
 * reissued, the new file gets a new generated name, and every page that linked
 * the old one now points at a file that has been deleted — or worse, still
 * points at last year's terms. Finding them all is a search through content.
 *
 * Stored as an id, the label, the file size and the type shown to the reader
 * all come from the library at render time. Replace the file, and every page
 * that links it is correct.
 *
 * ## What it emits
 *
 *     <a class="file-link" href="/media/..." data-ext="pdf">
 *         Terms of engagement <span class="file-meta">PDF, 240.5 KB</span>
 *     </a>
 *
 * The size is in the link text on purpose, not in a `title`: it tells somebody
 * on a metered connection what they are about to spend before they spend it,
 * and a `title` is invisible on a touchscreen.
 *
 * ## Escaping
 *
 * Shortcodes expand *after* the sanitiser has run, so nothing here is checked
 * by anything downstream. Every value written into the output is escaped at the
 * point it is written, and an unescaped one would be a stored XSS hole on every
 * page using the shortcode.
 */
component singleton accessors="true" {

	property name="mediaService" inject="MediaService@media";

	this.TAG         = "file";
	this.DESCRIPTION = 'Links a document from the library: [file id="12"]Optional label[/file]';

	string function render( struct attributes = {}, string body = "", struct context = {} ){
		var id = val( arguments.attributes.id ?: 0 );

		if ( !id ) {
			return "";
		}

		var item = mediaService.getById( id );

		// Scoped to the site being rendered: an id in a page's content must not
		// be able to pull another tenant's file.
		if ( isNull( item ) || item.getSiteId() != val( arguments.context.siteId ?: 0 ) ) {
			return "";
		}

		// An image has its own shortcode, which renders it rather than linking
		// it. Accepting one here would quietly produce a download link to a
		// photograph, which is never what `[file]` was reached for.
		if ( !item.isDocument() ) {
			return "";
		}

		// The author's label when they gave one, the library's otherwise. The
		// body has already been through the sanitiser as part of the page, but
		// it is a link's text and not a block of markup, so it is escaped as
		// text — a nested `<a>` would be invalid HTML anyway.
		var given = trim( arguments.body );
		var label = arguments.context.escape( len( given ) ? given : item.getEffectiveLabel() );

		var meta = arguments.context.escape( item.getTypeLabel() & ", " & item.getHumanSize() );

		return '<a class="file-link" href="' & xmlFormat( item.getUrl() ) & '"'
			& ' data-ext="' & xmlFormat( lCase( item.getExtension() ?: "" ) ) & '">'
			& label
			& ' <span class="file-meta">' & meta & "</span>"
			& "</a>";
	}

}
