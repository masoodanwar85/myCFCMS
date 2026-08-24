/**
 * The media library's admin screens, and the endpoint the editor uploads to.
 */
component extends="core.models.security.SecuredHandler" {

	property name="mediaService" inject="MediaService@media";
	property name="paginator"    inject="Paginator@core";

	variables.permissions = {
		"index"  : "media.view",
		"upload" : "media.upload",
		"inline" : "media.upload",
		"browse" : "media.view",
		"update" : "media.update",
		"remove" : "media.delete",
		"$every" : "media.view"
	};

	function index( event, rc, prc ){
		var siteId = prc.currentSite.getId();

		prc.pageTitle  = "Media";
		prc.pagination = paginator.paginate(
			total   = mediaService.countForSite( siteId ),
			page    = paginator.readPage( rc.page ?: 1 ),
			perPage = 24
		);
		prc.pageBase = "/admin/media";
		prc.items    = mediaService.getForSite( siteId, prc.pagination.perPage, prc.pagination.offset );
		prc.allowed  = mediaService.getAllowedExtensions();
		prc.maxMB    = numberFormat( mediaService.maxBytes() / 1048576, "9.9" );
		prc.usedMB   = numberFormat( mediaService.bytesUsedBySite( siteId ) / 1048576, "9.9" );

		prc.canUpload = authorization.can( prc.currentUser, "media.upload" );
		prc.canUpdate = authorization.can( prc.currentUser, "media.update" );
		prc.canDelete = authorization.can( prc.currentUser, "media.delete" );

		event.setView( view = "admin/index", module = "media" );
	}

	function upload( event, rc, prc ){
		try {
			mediaService.upload(
				siteId     = prc.currentSite.getId(),
				fileField  = "file",
				altText    = rc.altText ?: "",
				uploadedBy = prc.currentUser.getId()
			);
		} catch ( any e ) {
			return done( "/admin/media", e.message, "error" );
		}

		return done( "/admin/media", "File uploaded." );
	}

	function update( event, rc, prc ){
		try {
			mediaService.updateDetails(
				mediaId = val( rc.id ?: 0 ),
				siteId  = prc.currentSite.getId(),
				altText = rc.altText ?: "",
				title   = rc.title ?: ""
			);
		} catch ( any e ) {
			return done( "/admin/media", e.message, "error" );
		}

		return done( "/admin/media", "Details saved." );
	}

	function remove( event, rc, prc ){
		try {
			mediaService.deleteItem( val( rc.id ?: 0 ), prc.currentSite.getId() );
		} catch ( any e ) {
			return done( "/admin/media", e.message, "error" );
		}

		return done( "/admin/media", "File deleted." );
	}

	/**
	 * The editor's library picker.
	 *
	 * Returns this site's images as JSON so an author can insert one that is
	 * already uploaded instead of uploading it again. Scoped to
	 * `prc.currentSite` like every other read here, so the picker cannot list
	 * another tenant's files even if the id were guessed.
	 */
	function browse( event, rc, prc ){
		event.noLayout();

		var siteId = prc.currentSite.getId();
		var page   = paginator.paginate(
			total   = mediaService.countImagesForSite( siteId ),
			page    = paginator.readPage( rc.page ?: 1 ),
			perPage = 24
		);

		event.renderData(
			type = "json",
			data = {
				"items" : mediaService
					.getImagesForSite( siteId, page.perPage, page.offset )
					.map( ( item ) => item.getMemento() ),
				"page"       : page.page,
				"totalPages" : page.totalPages,
				"total"      : page.total
			}
		);
	}

	/**
	 * The editor's image upload.
	 *
	 * CKEditor posts one file and expects `{ "url": "..." }` back, or
	 * `{ "error": { "message": "..." } }` — which it shows to the author, so the
	 * messages here are written for a person rather than a log.
	 *
	 * JSON in, JSON out: this is called by script, not submitted by a form, so
	 * a redirect would be meaningless.
	 */
	function inline( event, rc, prc ){
		event.noLayout();

		try {
			var item = mediaService.upload(
				siteId     = prc.currentSite.getId(),
				fileField  = "upload",
				uploadedBy = prc.currentUser.getId()
			);

			event.renderData( type = "json", data = { "url" : item.getUrl() } );
		} catch ( any e ) {
			event.renderData(
				type       = "json",
				statusCode = 422,
				data       = { "error" : { "message" : e.message } }
			);
		}
	}

}
