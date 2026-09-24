/**
 * `[hero-slider]` — this site's published hero slides, in page content.
 *
 * The home template calls the same service method. This tag is how any other
 * page gets the same markup without knowing the module exists.
 */
component singleton accessors="true" {

	property name="slideService" inject="SlideService@slides";

	this.TAG         = "hero-slider";
	this.DESCRIPTION = "Embeds this site's hero slider: [hero-slider]";

	string function render( struct attributes = {}, string body = "", struct context = {} ){
		var siteId = val( arguments.context.siteId ?: 0 );

		if ( !siteId ) {
			return "";
		}

		return slideService.renderHeroSlider( siteId );
	}

}
