/**
 * Accepting and managing uploaded files.
 *
 * An upload endpoint is the classic way to get an executable file onto a
 * server, so this is written to distrust every part of what arrives: the
 * filename, the extension, the declared content type, and the bytes.
 *
 * The defences, and what each is actually for:
 *
 *   - **Stored outside the webroot.** Even a file that defeats every check
 *     below sits somewhere the web server will not execute.
 *   - **We name the file, never the uploader.** The submitted name is recorded
 *     for display and never used for a filesystem operation, so `../../` and
 *     null bytes have nowhere to go.
 *   - **Extension allow-list**, not a deny-list. A deny-list is a guess about
 *     what is dangerous; an allow-list is a statement about what is wanted.
 *   - **Content is verified**, not trusted. An image must actually decode as
 *     one; a PDF must start with `%PDF`. A `.png` full of PHP fails here.
 *   - **SVG is deliberately excluded** even though it is an image: it is XML
 *     that can carry script, and serving one from the site's own origin would
 *     hand an uploader cross-site scripting.
 *   - **Size cap**, so an upload cannot fill the disk.
 */
component singleton accessors="true" {

	property name="mediaRepository" inject="MediaRepository@media";
	property name="siteRepository"  inject="SiteRepository@core";
	property name="settings"        inject="coldbox:moduleSettings:media";
	property name="wirebox"         inject="wirebox";
	property name="log"             inject="logbox:logger:{this}";

	/**
	 * Extension -> the MIME type we will serve it as.
	 *
	 * The stored type comes from this table, not from the upload: a browser
	 * obeys the `Content-Type` we send, so letting an uploader choose it is
	 * letting them choose how their file is interpreted.
	 */
	variables.ALLOWED = {
		"jpg"  : "image/jpeg",
		"jpeg" : "image/jpeg",
		"png"  : "image/png",
		"gif"  : "image/gif",
		"webp" : "image/webp",
		"pdf"  : "application/pdf"
	};

	/**
	 * Accept an uploaded file.
	 *
	 * @siteId     Owning site.
	 * @fileField  Name of the form field holding the upload.
	 * @altText    Alternative text, for images.
	 * @uploadedBy The acting user.
	 *
	 * @throws Media.SiteNotFound
	 * @throws Media.NoFile
	 * @throws Media.TypeNotAllowed
	 * @throws Media.TooLarge
	 * @throws Media.ContentMismatch
	 */
	media.models.MediaItem function upload(
		required numeric siteId,
		string fileField = "file",
		string altText   = "",
		string title     = "",
		numeric uploadedBy
	){
		if ( isNull( siteRepository.findById( arguments.siteId ) ) ) {
			throw( type = "Media.SiteNotFound", message = "No site with id [#arguments.siteId#]." );
		}

		var staging = stagingRoot();
		ensureDirectory( staging );

		var upload = "";

		try {
			// Landed in staging first, so nothing reaches a served location
			// before it has been checked.
			upload = fileUpload( staging, arguments.fileField, "", "makeunique" );
		} catch ( any e ) {
			throw( type = "Media.NoFile", message = "No file was received.", detail = e.message );
		}

		var staged = staging & "/" & upload.serverFile;

		try {
			var extension = lCase( upload.serverFileExt ?: "" );

			if ( !structKeyExists( variables.ALLOWED, extension ) ) {
				throw(
					type    = "Media.TypeNotAllowed",
					message = "Files of type [#extension#] are not accepted.",
					detail  = "Accepted: " & structKeyList( variables.ALLOWED, ", " ) & "."
				);
			}

			var size = getFileInfo( staged ).size;

			if ( size > maxBytes() ) {
				throw(
					type    = "Media.TooLarge",
					message = "That file is larger than the #numberFormat( maxBytes() / 1048576, '9.9' )#MB limit."
				);
			}

			verifyContent( staged, extension );

			var dimensions = readDimensions( staged, extension );
			var stored     = storeFile( arguments.siteId, staged, extension, upload.clientFile ?: "upload" );

			var item = wirebox
				.getInstance( "MediaItem@media" )
				.setSiteId( arguments.siteId )
				.setFilename( stored.filename )
				.setOriginalFilename( left( upload.clientFile ?: "upload", 255 ) )
				.setStoredPath( stored.path )
				.setExtension( extension )
				.setMimeType( variables.ALLOWED[ extension ] )
				.setByteSize( size )
				.setAltText( left( trim( arguments.altText ), 255 ) )
				.setTitle( left( trim( arguments.title ), 255 ) );

			if ( structKeyExists( dimensions, "width" ) ) {
				item.setWidth( dimensions.width ).setHeight( dimensions.height );
			}
			if ( !isNull( arguments.uploadedBy ) ) {
				item.setUploadedBy( arguments.uploadedBy );
			}

			return mediaRepository.create( item );
		} finally {
			// Whatever happened, nothing stays in staging.
			if ( fileExists( staged ) ) {
				fileDelete( staged );
			}
		}
	}

	/**
	 * @throws Media.NotFound
	 * @throws Media.CrossTenant
	 */
	media.models.MediaItem function updateDetails(
		required numeric mediaId,
		required numeric siteId,
		string altText,
		string title
	){
		var item = requireForSite( arguments.mediaId, arguments.siteId );

		if ( !isNull( arguments.altText ) ) {
			item.setAltText( left( trim( arguments.altText ), 255 ) );
		}
		if ( !isNull( arguments.title ) ) {
			item.setTitle( left( trim( arguments.title ), 255 ) );
		}

		return mediaRepository.update( item );
	}

	/**
	 * Remove a file and its record.
	 *
	 * The row goes first: a record pointing at a file that is gone renders a
	 * broken image, but a file with no record is invisible and never cleaned up.
	 */
	function deleteItem( required numeric mediaId, required numeric siteId ){
		var item = requireForSite( arguments.mediaId, arguments.siteId );
		var path = absolutePath( arguments.siteId, item.getStoredPath() );

		mediaRepository.delete( item.getId() );

		if ( fileExists( path ) ) {
			try {
				fileDelete( path );
			} catch ( any e ) {
				log.warn( "Media record #item.getId()# removed but its file could not be deleted: #e.message#" );
			}
		}

		return this;
	}

	/* ----------------------------------------------------------------- reads */

	function getById( required numeric mediaId ){
		return mediaRepository.findById( arguments.mediaId );
	}

	/**
	 * Resolve a public path within one site.
	 */
	function getByPath( required numeric siteId, required string storedPath ){
		var safe = normalizePath( arguments.storedPath );

		if ( !len( safe ) ) {
			return;
		}

		return mediaRepository.findByPath( arguments.siteId, safe );
	}

	array function getForSite( required numeric siteId, numeric limit = 24, numeric offset = 0 ){
		return mediaRepository.findBySiteId( arguments.siteId, arguments.limit, arguments.offset );
	}

	/**
	 * What the editor's library picker shows. Images only: the picker inserts
	 * an `<img>`, and offering a PDF there would produce a broken one.
	 */
	array function getImagesForSite( required numeric siteId, numeric limit = 24, numeric offset = 0 ){
		return mediaRepository.findImagesBySiteId( arguments.siteId, arguments.limit, arguments.offset );
	}

	numeric function countImagesForSite( required numeric siteId ){
		return mediaRepository.countImagesBySiteId( arguments.siteId );
	}

	numeric function countForSite( required numeric siteId ){
		return mediaRepository.countBySiteId( arguments.siteId );
	}

	numeric function bytesUsedBySite( required numeric siteId ){
		return mediaRepository.sumBytesForSite( arguments.siteId );
	}

	/**
	 * Where a file actually lives. Never built from anything a user supplied.
	 */
	string function absolutePath( required numeric siteId, required string storedPath ){
		return mediaRoot() & "/" & arguments.siteId & "/" & normalizePath( arguments.storedPath );
	}

	array function getAllowedExtensions(){
		return structKeyArray( variables.ALLOWED ).sort( "textnocase" );
	}

	numeric function maxBytes(){
		return val( settings.maxUploadBytes ?: 10485760 );
	}

	/* -------------------------------------------------------------- internals */

	/**
	 * Confirm the bytes are what the extension claims.
	 */
	private function verifyContent( required string path, required string extension ){
		if ( arguments.extension == "pdf" ) {
			var head = "";

			try {
				head = left( fileRead( arguments.path, "utf-8" ), 5 );
			} catch ( any e ) {
				head = "";
			}

			if ( left( head, 4 ) != "%PDF" ) {
				throw(
					type    = "Media.ContentMismatch",
					message = "That file is not a PDF, whatever it is named."
				);
			}

			return this;
		}

		if ( !isImageFile( arguments.path ) ) {
			throw(
				type    = "Media.ContentMismatch",
				message = "That file is not a readable image, whatever it is named."
			);
		}

		return this;
	}

	private struct function readDimensions( required string path, required string extension ){
		if ( arguments.extension == "pdf" ) {
			return {};
		}

		try {
			var info = imageInfo( imageRead( arguments.path ) );
			return { "width" : info.width, "height" : info.height };
		} catch ( any e ) {
			// A readable image we cannot measure is still a usable image.
			return {};
		}
	}

	/**
	 * Move the staged file to its home under a name we chose.
	 *
	 * Dated subdirectories keep any one directory from growing without bound,
	 * and the random suffix means an unpublished file's URL cannot be guessed
	 * from its name.
	 */
	private struct function storeFile(
		required numeric siteId,
		required string staged,
		required string extension,
		required string clientFile
	){
		var folder   = dateFormat( now(), "yyyy" ) & "/" & dateFormat( now(), "mm" );
		var base     = safeBaseName( arguments.clientFile );
		var attempts = 0;

		while ( attempts < 5 ) {
			var filename = base & "-" & lCase( left( hash( createUUID(), "SHA-256" ), 8 ) ) & "." & arguments.extension;
			var relative = folder & "/" & filename;

			if ( !mediaRepository.existsByPath( arguments.siteId, relative ) ) {
				var target = absolutePath( arguments.siteId, relative );

				ensureDirectory( getDirectoryFromPath( target ) );
				fileMove( arguments.staged, target );

				return { "filename" : filename, "path" : relative };
			}

			attempts++;
		}

		throw( type = "Media.NameCollision", message = "Could not find a free filename." );
	}

	/**
	 * A recognisable, harmless stem from whatever the uploader called the file.
	 */
	private string function safeBaseName( required string clientFile ){
		var stem = reReplace( lCase( listFirst( arguments.clientFile, "." ) ), "[^a-z0-9]+", "-", "all" );
		stem     = reReplace( stem, "^-+|-+$", "", "all" );

		return len( stem ) ? left( stem, 60 ) : "file";
	}

	/**
	 * Strip anything that could climb out of the media root.
	 */
	private string function normalizePath( required string path ){
		var clean = replace( arguments.path, "\", "/", "all" );

		clean = reReplace( clean, "\.\.+", "", "all" );
		clean = reReplace( clean, "[^a-zA-Z0-9/_.-]", "", "all" );
		clean = reReplace( clean, "/+", "/", "all" );
		clean = reReplace( clean, "^/+|/+$", "", "all" );

		return clean;
	}

	private function requireForSite( required numeric mediaId, required numeric siteId ){
		var item = mediaRepository.findById( arguments.mediaId );

		if ( isNull( item ) ) {
			throw( type = "Media.NotFound", message = "No media item [#arguments.mediaId#]." );
		}

		if ( item.getSiteId() != arguments.siteId ) {
			throw(
				type    = "Media.CrossTenant",
				message = "Media item [#arguments.mediaId#] does not belong to site [#arguments.siteId#]."
			);
		}

		return item;
	}

	private string function mediaRoot(){
		return expandPath( settings.mediaRoot ?: "/storage/media" );
	}

	private string function stagingRoot(){
		return mediaRoot() & "/.staging";
	}

	private function ensureDirectory( required string path ){
		if ( !directoryExists( arguments.path ) ) {
			directoryCreate( arguments.path, true );
		}

		return this;
	}

}
