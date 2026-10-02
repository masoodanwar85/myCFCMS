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
		prc.usedMB   = numberFormat( mediaService.bytesUsedBySite( siteId ) / 1048576, "9.9" );

		// Two limits now, and the form has to say both: an author told "up to
		// 10MB" who is refused a 14MB PDF that the server would in fact have
		// taken has been misled by the screen, not by the file.
		prc.maxMB          = numberFormat( mediaService.maxBytes() / 1048576, "9.9" );
		prc.maxImageMB     = numberFormat( mediaService.maxBytesFor( "image" ) / 1048576, "9.9" );
		prc.maxDocumentMB  = numberFormat( mediaService.maxBytesFor( "document" ) / 1048576, "9.9" );
		prc.allowedImages  = mediaService.getAllowedExtensionsFor( "image" );
		prc.allowedDocs    = mediaService.getAllowedExtensionsFor( "document" );

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
				// What a `[file]` link says when the author gives no label, so
				// it is worth asking for at upload time rather than making
				// somebody come back and set it.
				title      = rc.title ?: "",
				uploadedBy = prc.currentUser.getId()
			);
		} catch ( any e ) {
			return done( "/admin/media", e.message, "error" );
		}

		return done( "/admin/media", "File uploaded." );
	}

	/**
	 * Only the fields actually posted are passed on.
	 *
	 * `updateDetails` leaves a field alone when its argument is null, and
	 * `rc.altText ?: ""` is never null — it is an empty string, which means
	 * "clear it". The library card now shows alt text for an image and a title
	 * for a document, so a form that posts one would wipe the other.
	 */
	function update( event, rc, prc ){
		var given = { "mediaId" : val( rc.id ?: 0 ), "siteId" : prc.currentSite.getId() };

		for ( var field in [ "altText", "title" ] ) {
			if ( structKeyExists( rc, field ) ) {
				given[ field ] = rc[ field ];
			}
		}

		try {
			mediaService.updateDetails( argumentCollection = given );
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
	/**
	 * The library, as JSON, for the picker.
	 *
	 * `kind` defaults to `image` rather than to everything: every caller that
	 * existed before documents did is inserting an `<img>` or filling an image
	 * field, and a default of "all" would start offering them PDFs.
	 */
	function browse( event, rc, prc ){
		event.noLayout();

		var siteId = prc.currentSite.getId();
		var kind   = len( trim( rc.kind ?: "" ) ) ? trim( rc.kind ) : "image";
		var page   = paginator.paginate(
			total   = mediaService.countByKindForSite( siteId, kind ),
			page    = paginator.readPage( rc.page ?: 1 ),
			perPage = 24
		);

		event.renderData(
			type = "json",
			data = {
				"items" : mediaService
					.getByKindForSite( siteId, kind, page.perPage, page.offset )
					.map( ( item ) => item.getMemento() ),
				"kind"       : kind,
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
