/**
 * Slide use cases.
 *
 * Validate and sanitise here. Render through the site's theme; know no HTTP.
 */
component singleton accessors="true" {

	property name="slideRepository" inject="SlideRepository@slides";
	property name="siteRepository"  inject="SiteRepository@core";
	property name="sanitizer"       inject="ContentSanitizer@core";
	property name="themeService"    inject="ThemeService@core";
	property name="log"             inject="logbox:logger:{this}";
	property name="wirebox"         inject="wirebox";

	/**
	 * @allowUnfilteredHtml Skip sanitising. The caller checks the permission.
	 *
	 * @throws Slides.SiteNotFound
	 * @throws Slides.InvalidSlide
	 */
	slides.models.Slide function createSlide(
		required numeric siteId,
		string imageUrl             = "",
		string imageAlt             = "",
		string overlayHtml          = "",
		string hAlign               = "left",
		string vAlign               = "middle",
		numeric sortOrder           = 0,
		boolean isPublished         = false,
		boolean allowUnfilteredHtml = false
	){
		if ( isNull( siteRepository.findById( arguments.siteId ) ) ) {
			throw( type = "Slides.SiteNotFound", message = "No site with id [#arguments.siteId#]." );
		}

		var slide = wirebox
			.getInstance( "Slide@slides" )
			.setSiteId( arguments.siteId )
			.setImageUrl( normaliseImageUrl( arguments.imageUrl ) )
			.setImageAlt( left( trim( arguments.imageAlt ), 255 ) )
			.setOverlayHtml( sanitizer.sanitize( arguments.overlayHtml, arguments.allowUnfilteredHtml ) )
			.setHAlign( fromList( arguments.hAlign, "left,center,right", "left" ) )
			.setVAlign( fromList( arguments.vAlign, "top,middle,bottom", "middle" ) )
			.setSortOrder(
				val( arguments.sortOrder ) > 0
					? val( arguments.sortOrder )
					: slideRepository.nextSortOrder( arguments.siteId )
			)
			.setIsPublished( arguments.isPublished ? true : false );

		requireContent( slide );

		return slideRepository.create( slide );
	}

	/**
	 * @throws Slides.SlideNotFound
	 * @throws Slides.InvalidSlide
	 */
	slides.models.Slide function updateSlide(
		required numeric slideId,
		string imageUrl             = "",
		string imageAlt             = "",
		string overlayHtml          = "",
		string hAlign               = "left",
		string vAlign               = "middle",
		numeric sortOrder           = 0,
		boolean isPublished         = false,
		boolean allowUnfilteredHtml = false
	){
		var slide = requireSlide( arguments.slideId );

		slide.setImageUrl( normaliseImageUrl( arguments.imageUrl ) );
		slide.setImageAlt( left( trim( arguments.imageAlt ), 255 ) );
		slide.setOverlayHtml( sanitizer.sanitize( arguments.overlayHtml, arguments.allowUnfilteredHtml ) );
		slide.setHAlign( fromList( arguments.hAlign, "left,center,right", "left" ) );
		slide.setVAlign( fromList( arguments.vAlign, "top,middle,bottom", "middle" ) );
		slide.setSortOrder( val( arguments.sortOrder ) );
		slide.setIsPublished( arguments.isPublished ? true : false );

		requireContent( slide );

		return slideRepository.update( slide );
	}

	slides.models.Slide function publishSlide( required numeric slideId ){
		var slide = requireSlide( arguments.slideId );

		slide.setIsPublished( true );

		return slideRepository.update( slide );
	}

	slides.models.Slide function unpublishSlide( required numeric slideId ){
		var slide = requireSlide( arguments.slideId );

		slide.setIsPublished( false );

		return slideRepository.update( slide );
	}

	function deleteSlide( required numeric slideId ){
		requireSlide( arguments.slideId );
		slideRepository.delete( arguments.slideId );

		return this;
	}

	function getSlideById( required numeric slideId ){
		return slideRepository.findById( arguments.slideId );
	}

	array function getSlidesForSite( required numeric siteId ){
		return slideRepository.findBySiteId( arguments.siteId );
	}

	array function getPublishedSlides( required numeric siteId ){
		return slideRepository.findPublished( arguments.siteId );
	}

	/**
	 * HTML for the home template and the shortcode. Empty when nothing is
	 * published, or when the theme has no `hero-slider` view — never a 500.
	 */
	string function renderHeroSlider( required numeric siteId ){
		var slides = getPublishedSlides( arguments.siteId );

		if ( !slides.len() ) {
			return "";
		}

		try {
			return themeService.renderView(
				theme = themeService.getThemeForSite( arguments.siteId ),
				view  = "hero-slider",
				args  = { "slides" : slides }
			);
		} catch ( any e ) {
			log.error( "Hero slider could not render: #e.message#", e );
			return "";
		}
	}

	private function requireSlide( required numeric slideId ){
		var slide = slideRepository.findById( arguments.slideId );

		if ( isNull( slide ) ) {
			throw( type = "Slides.SlideNotFound", message = "No slide with id [#arguments.slideId#]." );
		}

		return slide;
	}

	private function requireContent( required slides.models.Slide slide ){
		if ( !len( trim( arguments.slide.getImageUrl() ?: "" ) ) && !len( trim( arguments.slide.getOverlayHtml() ?: "" ) ) ) {
			throw(
				type    = "Slides.InvalidSlide",
				message = "A slide needs a background image or overlay HTML."
			);
		}
	}

	private string function normaliseImageUrl( required string value ){
		var address = trim( arguments.value );

		if ( !len( address ) ) {
			return "";
		}

		if ( reFindNoCase( "^(javascript|data|vbscript):", address ) ) {
			throw( type = "Slides.InvalidSlide", message = "That image URL is not allowed." );
		}

		if ( !reFindNoCase( "^(https?://|/)", address ) ) {
			throw(
				type    = "Slides.InvalidSlide",
				message = "The background image must start with http://, https:// or /."
			);
		}

		return left( address, 500 );
	}

	private string function fromList( required string value, required string allowed, required string fallback ){
		var candidate = lCase( trim( arguments.value ) );

		return listFindNoCase( arguments.allowed, candidate ) ? candidate : arguments.fallback;
	}

}
