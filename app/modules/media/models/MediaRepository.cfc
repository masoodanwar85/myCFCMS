/**
 * Persistence for uploaded files. Every read is scoped by site.
 */
component singleton extends="core.models.persistence.BaseRepository" {

	variables.TABLE   = "media";
	variables.COLUMNS = [
		"id", "site_id", "filename", "original_filename", "stored_path",
		"extension", "mime_type", "kind", "byte_size", "width", "height",
		"alt_text", "title", "uploaded_by", "created_at", "updated_at"
	];

	// The only values `kind` may hold. A query asking for anything else is a
	// bug, and gets an empty result rather than the whole library.
	variables.KINDS = [ "image", "document" ];

	media.models.MediaItem function create( required media.models.MediaItem item ){
		var stamp = now();

		var result = variables.query
			.from( variables.TABLE )
			.insert( {
				"site_id"           : arguments.item.getSiteId(),
				"filename"          : arguments.item.getFilename(),
				"original_filename" : arguments.item.getOriginalFilename(),
				"stored_path"       : arguments.item.getStoredPath(),
				"extension"         : arguments.item.getExtension(),
				"mime_type"         : arguments.item.getMimeType(),
				// Asked of the item, not of the argument: `getKind()` derives
				// it from the mime type when nothing set it, so a caller that
				// predates this column still stores a correct value.
				"kind"              : arguments.item.getKind(),
				"byte_size"         : arguments.item.getByteSize(),
				"width"             : nullableNumber( arguments.item.getWidth() ),
				"height"            : nullableNumber( arguments.item.getHeight() ),
				"alt_text"          : arguments.item.getAltText() ?: "",
				"title"             : arguments.item.getTitle() ?: "",
				"uploaded_by"       : nullableNumber( arguments.item.getUploadedBy() ),
				"created_at"        : { value : stamp, cfsqltype : "cf_sql_timestamp" },
				"updated_at"        : { value : stamp, cfsqltype : "cf_sql_timestamp" }
			} );

		arguments.item.setId( generatedKey( result, variables.TABLE ) );
		arguments.item.setCreatedAt( stamp );

		return arguments.item;
	}

	media.models.MediaItem function update( required media.models.MediaItem item ){
		variables.query
			.from( variables.TABLE )
			.where( "id", arguments.item.getId() )
			.update( {
				"alt_text"   : arguments.item.getAltText() ?: "",
				"title"      : arguments.item.getTitle() ?: "",
				"updated_at" : { value : now(), cfsqltype : "cf_sql_timestamp" }
			} );

		return arguments.item;
	}

	function findById( required numeric id ){
		return toItemOrNull( baseQuery().where( "id", arguments.id ).first() );
	}

	/**
	 * The lookup behind a public /media/... request. Scoped by site, so one
	 * tenant's domain can never serve another's file.
	 */
	function findByPath( required numeric siteId, required string storedPath ){
		return toItemOrNull(
			baseQuery().where( "site_id", arguments.siteId ).where( "stored_path", arguments.storedPath ).first()
		);
	}

	array function findBySiteId(
		required numeric siteId,
		numeric limit  = 24,
		numeric offset = 0
	){
		return baseQuery()
			.where( "site_id", arguments.siteId )
			.orderBy( "created_at", "desc" )
			.orderBy( "id", "desc" )
			.limit( arguments.limit )
			.offset( arguments.offset )
			.get()
			.map( ( row ) => toItem( row ) );
	}

	/**
	 * One kind of file, for the library picker.
	 *
	 * Filtering on `kind` rather than on `mime_type LIKE`: "every document" is
	 * then a statement about documents, instead of "everything that is not an
	 * image" — which would quietly include a video the day one can be uploaded.
	 */
	array function findByKindForSite(
		required numeric siteId,
		required string kind,
		numeric limit  = 24,
		numeric offset = 0
	){
		return kindQuery( arguments.siteId, arguments.kind )
			.select( variables.COLUMNS )
			.orderBy( "created_at", "desc" )
			.orderBy( "id", "desc" )
			.limit( arguments.limit )
			.offset( arguments.offset )
			.get()
			.map( ( row ) => toItem( row ) );
	}

	numeric function countByKindForSite( required numeric siteId, required string kind ){
		return kindQuery( arguments.siteId, arguments.kind ).count();
	}

	array function findImagesBySiteId(
		required numeric siteId,
		numeric limit  = 24,
		numeric offset = 0
	){
		return findByKindForSite( arguments.siteId, "image", arguments.limit, arguments.offset );
	}

	numeric function countImagesBySiteId( required numeric siteId ){
		return countByKindForSite( arguments.siteId, "image" );
	}

	numeric function countBySiteId( required numeric siteId ){
		return variables.query.from( variables.TABLE ).where( "site_id", arguments.siteId ).count();
	}

	numeric function sumBytesForSite( required numeric siteId ){
		var row = variables.query
			.from( variables.TABLE )
			.selectRaw( "COALESCE(SUM(byte_size), 0) AS total" )
			.where( "site_id", arguments.siteId )
			.first();

		return row.isEmpty() ? 0 : val( row.total );
	}

	boolean function existsByPath( required numeric siteId, required string storedPath ){
		return variables.query
			.from( variables.TABLE )
			.where( "site_id", arguments.siteId )
			.where( "stored_path", arguments.storedPath )
			.exists();
	}

	function delete( required numeric id ){
		variables.query.from( variables.TABLE ).where( "id", arguments.id ).delete();
		return this;
	}

	media.models.MediaItem function toItem( required struct row ){
		var item = wirebox
			.getInstance( "MediaItem@media" )
			.setId( arguments.row.id )
			.setSiteId( arguments.row.site_id )
			.setFilename( arguments.row.filename )
			.setOriginalFilename( arguments.row.original_filename )
			.setStoredPath( arguments.row.stored_path )
			.setExtension( arguments.row.extension )
			.setMimeType( arguments.row.mime_type )
			.setKind( arguments.row.kind ?: "" )
			.setByteSize( arguments.row.byte_size )
			.setAltText( arguments.row.alt_text ?: "" )
			.setTitle( arguments.row.title ?: "" )
			.setCreatedAt( arguments.row.created_at )
			.setUpdatedAt( arguments.row.updated_at );

		if ( hasValue( arguments.row, "width" ) ) {
			item.setWidth( arguments.row.width );
		}
		if ( hasValue( arguments.row, "height" ) ) {
			item.setHeight( arguments.row.height );
		}
		if ( hasValue( arguments.row, "uploaded_by" ) ) {
			item.setUploadedBy( arguments.row.uploaded_by );
		}

		return item;
	}

	private function baseQuery(){
		return variables.query.from( variables.TABLE ).select( variables.COLUMNS );
	}

	/**
	 * An unknown kind matches nothing.
	 *
	 * `kind` reaches this from a query string, and the alternative to refusing
	 * an unrecognised one is a `WHERE` clause that drops away and returns the
	 * entire library to a picker that asked for one slice of it.
	 */
	private function kindQuery( required numeric siteId, required string kind ){
		var wanted = lCase( trim( arguments.kind ) );

		return variables.query
			.from( variables.TABLE )
			.where( "site_id", arguments.siteId )
			.where( "kind", variables.KINDS.findNoCase( wanted ) ? wanted : "__none__" );
	}

	private function toItemOrNull( required struct row ){
		if ( arguments.row.isEmpty() ) {
			return;
		}
		return toItem( arguments.row );
	}

	private boolean function hasValue( required struct row, required string key ){
		return structKeyExists( arguments.row, arguments.key )
			&& !isNull( arguments.row[ arguments.key ] )
			&& len( arguments.row[ arguments.key ] );
	}

	private struct function nullableNumber( value ){
		return {
			value     : isNull( arguments.value ) ? "" : arguments.value,
			cfsqltype : "cf_sql_bigint",
			null      : isNull( arguments.value )
		};
	}

}
