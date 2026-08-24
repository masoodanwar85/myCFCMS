/**
 * `[image id="12" align="right" width="320"]An optional caption[/image]`
 *
 * Lets an author place a library image somewhere the editor cannot reach — a
 * template, a snippet reused across pages — and, more usefully, means the image
 * is stored as a *reference*. The alt text comes from the library at render
 * time, so correcting it once corrects it everywhere.
 *
 * Every value written into the output is escaped. Handler output skips the
 * sanitiser, so an unescaped attribute here would be a stored XSS hole on every
 * page using the shortcode.
 */
component singleton accessors="true" {

	property name="mediaService" inject="MediaService@media";

	this.TAG         = "image";
	this.DESCRIPTION = 'Places an image from the library: [image id="12" align="right"]Caption[/image]';

	// A closed list, so `align` cannot become an arbitrary class name — or
	// anything else — in the rendered markup.
	variables.ALIGNMENTS = "left,right,center";

	string function render( struct attributes = {}, string body = "", struct context = {} ){
		var id = val( arguments.attributes.id ?: 0 );

		if ( !id ) {
			return "";
		}

		var item = mediaService.getById( id );

		// Scoped to the site being rendered: an id in a page's content must not
		// be able to pull another tenant's file.
		if ( isNull( item ) || item.getSiteId() != val( arguments.context.siteId ?: 0 ) || !item.isImage() ) {
			return "";
		}

		var classes = [ "shortcode-image" ];
		var align   = lCase( trim( arguments.attributes.align ?: "" ) );

		if ( listFindNoCase( variables.ALIGNMENTS, align ) ) {
			classes.append( "align-" & align );
		}

		// A caption in the body is author HTML that has already been through
		// the sanitiser as part of the page, so it is emitted as markup. The
		// alt text comes from the library and is escaped as an attribute.
		var caption = trim( arguments.body );
		var alt     = arguments.context.escape( item.getEffectiveAlt() );
		var width   = val( arguments.attributes.width ?: 0 );

		var img = '<img src="' & xmlFormat( item.getUrl() ) & '" alt="' & alt & '"'
			& ( width ? ' width="' & width & '"' : "" )
			& ' loading="lazy">';

		if ( !len( caption ) ) {
			return '<span class="' & classes.toList( " " ) & '">' & img & "</span>";
		}

		return '<figure class="' & classes.toList( " " ) & '">' & img
			& "<figcaption>" & caption & "</figcaption></figure>";
	}

}
