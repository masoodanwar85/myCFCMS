/**
 * Persistence for uploaded files. Every read is scoped by site.
 */
component singleton extends="core.models.persistence.BaseRepository" {

	variables.TABLE   = "media";
	variables.COLUMNS = [
		"id", "site_id", "filename", "original_filename", "stored_path",
		"extension", "mime_type", "byte_size", "width", "height",
		"alt_text", "title", "uploaded_by", "created_at", "updated_at"
	];

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
	 * Images only, for the editor's library picker. Filtering on `mime_type`
	 * rather than on the extension list: the mime type is what the upload
	 * actually verified, and an extension is only a claim about the bytes.
	 */
	array function findImagesBySiteId(
		required numeric siteId,
		numeric limit  = 24,
		numeric offset = 0
	){
		return imageQuery( arguments.siteId )
			.select( variables.COLUMNS )
			.orderBy( "created_at", "desc" )
			.orderBy( "id", "desc" )
			.limit( arguments.limit )
			.offset( arguments.offset )
			.get()
			.map( ( row ) => toItem( row ) );
	}

	numeric function countImagesBySiteId( required numeric siteId ){
		return imageQuery( arguments.siteId ).count();
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

	private function imageQuery( required numeric siteId ){
		return variables.query
			.from( variables.TABLE )
			.where( "site_id", arguments.siteId )
			.where( "mime_type", "like", "image/%" );
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
