/**
 * Images without alt text.
 *
 * `alt=""` is deliberately *not* a finding. An empty alt is the correct,
 * standards-sanctioned way to say "this image is decorative, skip it" — a
 * background flourish, a divider, a hero that repeats the heading next to it.
 * Treating it as missing would make this check nag about images that are
 * already right, and a check that cries wolf gets switched off.
 *
 * A missing `alt` attribute is the finding: nobody decided anything, the
 * attribute just is not there.
 *
 * This check in particular needs the rendered page. Featured images come from
 * the theme, `[image]` shortcodes expand at render time, and an inherited
 * featured image is not in this page's row at all — none of those `<img>` tags
 * exist in stored content.
 */
component singleton accessors="true" {

	this.ID = "image";

	array function inspect( required any document, required struct context ){
		var missing = arguments.document.images().filter( ( image ) => !image.hasAlt );

		if ( !missing.len() ) {
			return [];
		}

		return [ {
			"checkId"  : "image.missingAlt",
			"severity" : "warning",
			"message"  : missing.len() == 1
				? "One image has no alt attribute."
				: "#missing.len()# images have no alt attribute.",
			// The sources, so the offending image can be found without
			// hunting through the page.
			"detail"   : missing.map( ( image ) => len( image.src ) ? image.src : "(no src)" ).toList( " | " )
		} ];
	}

}
