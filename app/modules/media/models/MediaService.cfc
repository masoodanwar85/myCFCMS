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
	 * Extension -> what we will serve it as, what sort of thing it is, and how
	 * its bytes are checked.
	 *
	 * The stored type comes from this table, not from the upload: a browser
	 * obeys the `Content-Type` we send, so letting an uploader choose it is
	 * letting them choose how their file is interpreted.
	 *
	 * `signatures` are hex prefixes, any one of which the file may start with.
	 * An empty array means **the format has no signature to check** — see
	 * `verifyContent` for what stands in for it. An `image` kind is not checked
	 * against bytes here at all; it has to decode as an image, which is a far
	 * stronger test than a prefix.
	 *
	 * ## What is deliberately absent, and why
	 *
	 * `svg` — XML that can carry script, served from the site's own origin.
	 *
	 * `zip` — a container for arbitrary files. Accepting one turns the client's
	 * domain into somewhere a payload can be published and linked to, and no
	 * check on the archive can say what a reader will do with its contents.
	 *
	 * `doc`, `xls`, `ppt` — the pre-2007 OLE2 formats. Two reasons, and the
	 * second is the deciding one: they are macro-capable, and all three share
	 * the signature `D0CF11E0A1B11AE1`, so a `.xls` full of a Word document
	 * with macros passes any check this table could make. The modern XML
	 * formats below are the supported route. If a client genuinely needs to
	 * publish legacy Office files, adding the extension here is a one-line
	 * change — made in the knowledge that the signature proves nothing beyond
	 * "an OLE2 container".
	 */
	variables.ALLOWED = {
		"jpg"  : { "mime" : "image/jpeg",  "kind" : "image", "signatures" : [] },
		"jpeg" : { "mime" : "image/jpeg",  "kind" : "image", "signatures" : [] },
		"png"  : { "mime" : "image/png",   "kind" : "image", "signatures" : [] },
		"gif"  : { "mime" : "image/gif",   "kind" : "image", "signatures" : [] },
		"webp" : { "mime" : "image/webp",  "kind" : "image", "signatures" : [] },

		"pdf"  : { "mime" : "application/pdf", "kind" : "document", "signatures" : [ "25504446" ] },

		// All three are ZIP containers, so the signature confirms the
		// container and not the format. See `verifyContent`.
		"docx" : {
			"mime"       : "application/vnd.openxmlformats-officedocument.wordprocessingml.document",
			"kind"       : "document",
			"signatures" : [ "504B0304", "504B0506", "504B0708" ]
		},
		"xlsx" : {
			"mime"       : "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
			"kind"       : "document",
			"signatures" : [ "504B0304", "504B0506", "504B0708" ]
		},
		"pptx" : {
			"mime"       : "application/vnd.openxmlformats-officedocument.presentationml.presentation",
			"kind"       : "document",
			"signatures" : [ "504B0304", "504B0506", "504B0708" ]
		},

		// Plain text has no signature in existence to check against.
		"csv"  : { "mime" : "text/csv",   "kind" : "document", "signatures" : [] },
		"txt"  : { "mime" : "text/plain", "kind" : "document", "signatures" : [] }
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

			var spec = variables.ALLOWED[ extension ];
			var cap  = maxBytesFor( spec.kind );
			var size = getFileInfo( staged ).size;

			// Documents get their own, larger allowance: a scanned contract is
			// routinely bigger than any photograph on the site.
			if ( size > cap ) {
				throw(
					type    = "Media.TooLarge",
					message = "That #spec.kind# is larger than the #numberFormat( cap / 1048576, '9.9' )#MB limit for #spec.kind#s."
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
				.setMimeType( spec.mime )
				.setKind( spec.kind )
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
	 * One kind of file, for whichever picker asked.
	 *
	 * The picker is opened for a purpose — an `<img>` to insert, a logo field
	 * to fill, a link to place — and each wants one kind. Offering a PDF where
	 * an `<img>` is going produces a broken image; offering a photograph where
	 * a download link is going produces a link nobody wanted.
	 */
	array function getByKindForSite(
		required numeric siteId,
		required string kind,
		numeric limit  = 24,
		numeric offset = 0
	){
		return mediaRepository.findByKindForSite(
			arguments.siteId,
			arguments.kind,
			arguments.limit,
			arguments.offset
		);
	}

	numeric function countByKindForSite( required numeric siteId, required string kind ){
		return mediaRepository.countByKindForSite( arguments.siteId, arguments.kind );
	}

	array function getImagesForSite( required numeric siteId, numeric limit = 24, numeric offset = 0 ){
		return getByKindForSite( arguments.siteId, "image", arguments.limit, arguments.offset );
	}

	numeric function countImagesForSite( required numeric siteId ){
		return countByKindForSite( arguments.siteId, "image" );
	}

	array function getDocumentsForSite( required numeric siteId, numeric limit = 24, numeric offset = 0 ){
		return getByKindForSite( arguments.siteId, "document", arguments.limit, arguments.offset );
	}

	numeric function countDocumentsForSite( required numeric siteId ){
		return countByKindForSite( arguments.siteId, "document" );
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

	/**
	 * The extensions of one kind, for an upload field's `accept` attribute and
	 * for telling an author what will be taken.
	 */
	array function getAllowedExtensionsFor( required string kind ){
		var wanted = lCase( trim( arguments.kind ) );

		return structKeyArray( variables.ALLOWED )
			.filter( ( ext ) => variables.ALLOWED[ ext ].kind == wanted )
			.sort( "textnocase" );
	}

	/**
	 * The size limit for a kind.
	 *
	 * Two limits rather than one because the two are not comparable: 10MB is
	 * generous for a photograph and tight for a scanned forty-page contract. An
	 * unrecognised kind gets the smaller of the two, so a mistake is restrictive
	 * rather than permissive.
	 */
	numeric function maxBytesFor( required string kind ){
		var images    = val( settings.maxImageBytes ?: settings.maxUploadBytes ?: 10485760 );
		var documents = val( settings.maxDocumentBytes ?: 26214400 );

		if ( lCase( trim( arguments.kind ) ) == "document" ) {
			return documents;
		}

		if ( lCase( trim( arguments.kind ) ) == "image" ) {
			return images;
		}

		return min( images, documents );
	}

	/**
	 * The image limit. Kept because it is the one every caller before this
	 * group meant, and because `maxBytesFor()` is the honest name for the
	 * question now that there are two answers.
	 */
	numeric function maxBytes(){
		return maxBytesFor( "image" );
	}

	/* -------------------------------------------------------------- internals */

	/**
	 * Confirm the bytes are what the extension claims — as far as the format
	 * allows anyone to confirm it.
	 *
	 * Three cases, in descending order of how much they prove:
	 *
	 *  1. **An image must decode.** Not a prefix check: the file is handed to
	 *     the image reader, and a `.png` full of PHP fails because it is not a
	 *     picture.
	 *
	 *  2. **A signed document must start with its signature.** This catches the
	 *     mislabelled file, which is the realistic case. It does *not* identify
	 *     the format: `docx`, `xlsx` and `pptx` are all ZIP archives and share
	 *     one signature, so this proves "a ZIP container", and the extension
	 *     decides which of the three it is served as. Proving more would mean
	 *     opening the archive and looking for `word/document.xml`, which needs
	 *     ColdFusion's `zip` package — present on a full install, absent on the
	 *     minimal one this is developed against, so it would turn a verified
	 *     upload into an environment-dependent one.
	 *
	 *  3. **Plain text cannot be checked at all.** `csv` and `txt` have no
	 *     signature; any bytes are a valid text file. What makes that
	 *     acceptable is not this function but the serving policy: `Media.cfc`
	 *     sends every non-image as `Content-Disposition: attachment` with
	 *     `X-Content-Type-Options: nosniff`, so a `.txt` full of HTML is
	 *     downloaded as a text file rather than rendered as a page on the
	 *     site's own origin.
	 */
	private function verifyContent( required string path, required string extension ){
		var spec = variables.ALLOWED[ arguments.extension ];

		if ( spec.kind == "image" ) {
			if ( !isImageFile( arguments.path ) ) {
				throw(
					type    = "Media.ContentMismatch",
					message = "That file is not a readable image, whatever it is named."
				);
			}

			return this;
		}

		if ( !arrayLen( spec.signatures ) ) {
			return this;
		}

		var head = readHeadHex( arguments.path, 8 );

		for ( var signature in spec.signatures ) {
			if ( left( head, len( signature ) ) == signature ) {
				return this;
			}
		}

		throw(
			type    = "Media.ContentMismatch",
			message = "That file is not a #uCase( arguments.extension )#, whatever it is named."
		);
	}

	/**
	 * The first bytes of a file, as uppercase hex.
	 *
	 * Read as binary rather than through `fileRead( path, "utf-8" )`. The old
	 * PDF check used the text form and worked only because `%PDF` happens to be
	 * ASCII; a ZIP's `PK\x03\x04` contains control bytes that character
	 * decoding can substitute or drop, and the comparison would then fail on a
	 * perfectly good file.
	 */
	private string function readHeadHex( required string path, required numeric bytes ){
		try {
			var stream = fileOpen( arguments.path, "readbinary" );

			try {
				var head = fileRead( stream, arguments.bytes );

				return uCase( binaryEncode( head, "hex" ) );
			} finally {
				fileClose( stream );
			}
		} catch ( any e ) {
			// An unreadable file is not a verified file.
			return "";
		}
	}

	private struct function readDimensions( required string path, required string extension ){
		// Only an image has dimensions. Keyed off the kind rather than a list
		// of extensions that do not, so a new document type does not have to
		// remember to exclude itself here.
		if ( variables.ALLOWED[ arguments.extension ].kind != "image" ) {
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
			// directoryCreate( arguments.path, true );
			directoryCreate( arguments.path );
		}

		return this;
	}

}
