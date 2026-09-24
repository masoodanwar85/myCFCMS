/**
 * The Slides module's admin screens, at /admin/slides.
 */
component extends="core.models.security.SecuredHandler" {

	property name="slideService" inject="SlideService@slides";

	variables.permissions = {
		"index"     : "slides.view",
		"new"       : "slides.manage",
		"create"    : "slides.manage",
		"edit"      : "slides.manage",
		"update"    : "slides.manage",
		"publish"   : "slides.manage",
		"unpublish" : "slides.manage",
		"remove"    : "slides.manage",
		"$every"    : "slides.view"
	};

	function index( event, rc, prc ){
		prc.pageTitle = "Slides";
		prc.slides    = slideService.getSlidesForSite( prc.currentSite.getId() );
		prc.canManage = authorization.can( prc.currentUser, "slides.manage" );

		event.setView( view = "admin/index", module = "slides" );
	}

	function new( event, rc, prc ){
		prc.pageTitle = "New slide";
		prc.slide     = "";
		prc.useEditor = true;

		event.setView( view = "admin/form", module = "slides" );
	}

	function create( event, rc, prc ){
		try {
			slideService.createSlide(
				siteId              = prc.currentSite.getId(),
				imageUrl            = rc.imageUrl ?: "",
				imageAlt            = rc.imageAlt ?: "",
				overlayHtml         = rc.overlayHtml ?: "",
				hAlign              = rc.hAlign ?: "left",
				vAlign              = rc.vAlign ?: "middle",
				sortOrder           = val( rc.sortOrder ?: 0 ),
				isPublished         = ( rc.isPublished ?: "" ) == "on",
				allowUnfilteredHtml = mayPostRawHtml( prc )
			);
		} catch ( any e ) {
			return done( "/admin/slides/new", e.message, "error" );
		}

		return done( "/admin/slides", "Slide created." );
	}

	function edit( event, rc, prc ){
		prc.slide     = requireSiteSlide( rc.id ?: 0, prc );
		prc.pageTitle = "Edit slide";
		prc.useEditor = true;

		event.setView( view = "admin/form", module = "slides" );
	}

	function update( event, rc, prc ){
		var slide = requireSiteSlide( rc.id ?: 0, prc );

		try {
			slideService.updateSlide(
				slideId             = slide.getId(),
				imageUrl            = rc.imageUrl ?: "",
				imageAlt            = rc.imageAlt ?: "",
				overlayHtml         = rc.overlayHtml ?: "",
				hAlign              = rc.hAlign ?: "left",
				vAlign              = rc.vAlign ?: "middle",
				sortOrder           = val( rc.sortOrder ?: 0 ),
				isPublished         = ( rc.isPublished ?: "" ) == "on",
				allowUnfilteredHtml = mayPostRawHtml( prc )
			);
		} catch ( any e ) {
			return done( "/admin/slides/edit/" & slide.getId(), e.message, "error" );
		}

		return done( "/admin/slides", "Slide saved." );
	}

	function publish( event, rc, prc ){
		slideService.publishSlide( requireSiteSlide( rc.id ?: 0, prc ).getId() );

		return done( "/admin/slides", "Slide published." );
	}

	function unpublish( event, rc, prc ){
		slideService.unpublishSlide( requireSiteSlide( rc.id ?: 0, prc ).getId() );

		return done( "/admin/slides", "Slide unpublished." );
	}

	function remove( event, rc, prc ){
		slideService.deleteSlide( requireSiteSlide( rc.id ?: 0, prc ).getId() );

		return done( "/admin/slides", "Slide deleted." );
	}

	private boolean function mayPostRawHtml( required struct prc ){
		return authorization.can( arguments.prc.currentUser, "content.unfiltered" );
	}

	private function requireSiteSlide( required numeric slideId, required struct prc ){
		var slide = slideService.getSlideById( arguments.slideId );

		if ( isNull( slide ) || slide.getSiteId() != arguments.prc.currentSite.getId() ) {
			throw( type = "Admin.NotFoundHere", message = "No slide [#arguments.slideId#] on this site." );
		}

		return slide;
	}

}
