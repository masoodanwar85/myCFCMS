/**
 * Persistence for pages.
 *
 * Every read is scoped by `site_id`. There is deliberately no "find by id"
 * that ignores tenancy in the public read path — `findById` exists because the
 * service needs it to load a page it is about to check, and the service is what
 * enforces that the caller may touch it.
 *
 * Extends Core's BaseRepository, which is the only thing this module borrows
 * from Core's persistence layer.
 */
component singleton extends="core.models.persistence.BaseRepository" {

	variables.TABLE   = "pages";
	variables.COLUMNS = [
		"id",
		"site_id",
		"parent_id",
		"title",
		"slug",
		"path",
		"status",
		"content",
		"meta_title",
		"meta_description",
		"sort_order",
		"published_at",
		"created_by",
		"updated_by",
		"created_at",
		"updated_at"
	];

	/**
	 * @throws Pages.PathAlreadyExists when the site already has a page at that path.
	 */
	pages.models.Page function create( required pages.models.Page page ){
		var stamp  = now();
		var result = "";

		try {
			result = variables.query
				.from( variables.TABLE )
				.insert( {
					"site_id"          : arguments.page.getSiteId(),
					"parent_id"        : nullableId( arguments.page.getParentId() ),
					"title"            : arguments.page.getTitle(),
					"slug"             : arguments.page.getSlug(),
					"path"             : arguments.page.getPath(),
					"status"           : arguments.page.getStatus(),
					"content"          : { value : arguments.page.getContent() ?: "", cfsqltype : "cf_sql_longvarchar" },
					"meta_title"       : arguments.page.getMetaTitle() ?: "",
					"meta_description" : arguments.page.getMetaDescription() ?: "",
					"sort_order"       : arguments.page.getSortOrder(),
					"published_at"     : nullableTimestamp( arguments.page.getPublishedAt() ),
					"created_by"       : nullableId( arguments.page.getCreatedBy() ),
					"updated_by"       : nullableId( arguments.page.getUpdatedBy() ),
					"created_at"       : { value : stamp, cfsqltype : "cf_sql_timestamp" },
					"updated_at"       : { value : stamp, cfsqltype : "cf_sql_timestamp" }
				} );
		} catch ( any e ) {
			if ( !isUniqueViolation( e ) ) {
				rethrow;
			}
			throw(
				type    = "Pages.PathAlreadyExists",
				message = "This site already has a page at [#arguments.page.getPath()#].",
				detail  = e.message
			);
		}

		arguments.page.setId( generatedKey( result, variables.TABLE ) );
		arguments.page.setCreatedAt( stamp );
		arguments.page.setUpdatedAt( stamp );

		return arguments.page;
	}

	pages.models.Page function update( required pages.models.Page page ){
		var stamp = now();

		try {
			variables.query
				.from( variables.TABLE )
				.where( "id", arguments.page.getId() )
				.update( {
					"parent_id"        : nullableId( arguments.page.getParentId() ),
					"title"            : arguments.page.getTitle(),
					"slug"             : arguments.page.getSlug(),
					"path"             : arguments.page.getPath(),
					"status"           : arguments.page.getStatus(),
					"content"          : { value : arguments.page.getContent() ?: "", cfsqltype : "cf_sql_longvarchar" },
					"meta_title"       : arguments.page.getMetaTitle() ?: "",
					"meta_description" : arguments.page.getMetaDescription() ?: "",
					"sort_order"       : arguments.page.getSortOrder(),
					"published_at"     : nullableTimestamp( arguments.page.getPublishedAt() ),
					"updated_by"       : nullableId( arguments.page.getUpdatedBy() ),
					"updated_at"       : { value : stamp, cfsqltype : "cf_sql_timestamp" }
				} );
		} catch ( any e ) {
			if ( !isUniqueViolation( e ) ) {
				rethrow;
			}
			throw(
				type    = "Pages.PathAlreadyExists",
				message = "This site already has a page at [#arguments.page.getPath()#].",
				detail  = e.message
			);
		}

		arguments.page.setUpdatedAt( stamp );

		return arguments.page;
	}

	function findById( required numeric id ){
		return toPageOrNull(
			baseQuery().where( "id", arguments.id ).first()
		);
	}

	/**
	 * The lookup a router will use: one site, one path, one unique-index read.
	 */
	function findByPath( required numeric siteId, required string path ){
		return toPageOrNull(
			baseQuery().where( "site_id", arguments.siteId ).where( "path", arguments.path ).first()
		);
	}

	/**
	 * As `findByPath`, but only returns a page the public should see.
	 */
	function findPublishedByPath( required numeric siteId, required string path ){
		return toPageOrNull(
			baseQuery()
				.where( "site_id", arguments.siteId )
				.where( "path", arguments.path )
				.where( "status", "published" )
				.first()
		);
	}

	boolean function existsByPath( required numeric siteId, required string path ){
		return variables.query
			.from( variables.TABLE )
			.where( "site_id", arguments.siteId )
			.where( "path", arguments.path )
			.exists();
	}

	array function findBySiteId( required numeric siteId ){
		return baseQuery()
			.where( "site_id", arguments.siteId )
			.orderBy( "path" )
			.get()
			.map( ( row ) => toPage( row ) );
	}

	array function findPublishedBySiteId( required numeric siteId ){
		return baseQuery()
			.where( "site_id", arguments.siteId )
			.where( "status", "published" )
			.orderBy( "path" )
			.get()
			.map( ( row ) => toPage( row ) );
	}

	/**
	 * A site's top-level pages, in menu order.
	 */
	array function findRootPages( required numeric siteId ){
		return baseQuery()
			.where( "site_id", arguments.siteId )
			.whereNull( "parent_id" )
			.orderBy( "sort_order" )
			.orderBy( "title" )
			.get()
			.map( ( row ) => toPage( row ) );
	}

	array function findChildren( required numeric parentId ){
		return baseQuery()
			.where( "parent_id", arguments.parentId )
			.orderBy( "sort_order" )
			.orderBy( "title" )
			.get()
			.map( ( row ) => toPage( row ) );
	}

	boolean function hasChildren( required numeric parentId ){
		return variables.query.from( variables.TABLE ).where( "parent_id", arguments.parentId ).exists();
	}

	/**
	 * Everything beneath a page, found by path prefix rather than by walking
	 * the tree one level at a time.
	 */
	array function findDescendants( required numeric siteId, required string path ){
		return baseQuery()
			.where( "site_id", arguments.siteId )
			.whereLike( "path", arguments.path & "/%" )
			.orderBy( "path" )
			.get()
			.map( ( row ) => toPage( row ) );
	}

	/**
	 * Rewrite the path prefix of an entire subtree in one statement.
	 *
	 * Called after a rename or a move. Doing it row by row would be a query per
	 * descendant, and a partial failure would leave the tree inconsistent.
	 *
	 * @return The number of descendants rewritten.
	 */
	numeric function rewriteDescendantPaths(
		required numeric siteId,
		required string oldPath,
		required string newPath
	){
		queryExecute(
			"
			UPDATE pages
			SET path       = CONCAT( :newPath, SUBSTRING( path, :prefixLength ) ),
				updated_at = :updatedAt
			WHERE site_id = :siteId
			  AND path LIKE :pathPrefix
			",
			{
				newPath      : { value : arguments.newPath, cfsqltype : "cf_sql_varchar" },
				prefixLength : { value : len( arguments.oldPath ) + 1, cfsqltype : "cf_sql_integer" },
				updatedAt    : { value : now(), cfsqltype : "cf_sql_timestamp" },
				siteId       : { value : arguments.siteId, cfsqltype : "cf_sql_bigint" },
				pathPrefix   : { value : arguments.oldPath & "/%", cfsqltype : "cf_sql_varchar" }
			},
			{ result : "local.updateResult" }
		);

		return local.updateResult.recordCount ?: 0;
	}

	function updateSortOrder( required numeric pageId, required numeric sortOrder ){
		variables.query
			.from( variables.TABLE )
			.where( "id", arguments.pageId )
			.update( {
				"sort_order" : arguments.sortOrder,
				"updated_at" : { value : now(), cfsqltype : "cf_sql_timestamp" }
			} );

		return this;
	}

	function delete( required numeric pageId ){
		variables.query.from( variables.TABLE ).where( "id", arguments.pageId ).delete();
		return this;
	}

	pages.models.Page function toPage( required struct row ){
		var page = wirebox
			.getInstance( "Page@pages" )
			.setId( arguments.row.id )
			.setSiteId( arguments.row.site_id )
			.setTitle( arguments.row.title )
			.setSlug( arguments.row.slug )
			.setPath( arguments.row.path )
			.setStatus( arguments.row.status )
			.setContent( arguments.row.content ?: "" )
			.setMetaTitle( arguments.row.meta_title ?: "" )
			.setMetaDescription( arguments.row.meta_description ?: "" )
			.setSortOrder( arguments.row.sort_order )
			.setCreatedAt( arguments.row.created_at )
			.setUpdatedAt( arguments.row.updated_at );

		// Left unset when null, so `isRoot()` and the memento stay honest.
		if ( hasValue( arguments.row, "parent_id" ) ) {
			page.setParentId( arguments.row.parent_id );
		}
		if ( hasValue( arguments.row, "published_at" ) ) {
			page.setPublishedAt( arguments.row.published_at );
		}
		if ( hasValue( arguments.row, "created_by" ) ) {
			page.setCreatedBy( arguments.row.created_by );
		}
		if ( hasValue( arguments.row, "updated_by" ) ) {
			page.setUpdatedBy( arguments.row.updated_by );
		}

		return page;
	}

	private function baseQuery(){
		return variables.query.from( variables.TABLE ).select( variables.COLUMNS );
	}

	private function toPageOrNull( required struct row ){
		if ( arguments.row.isEmpty() ) {
			return;
		}
		return toPage( arguments.row );
	}

	private boolean function hasValue( required struct row, required string key ){
		return structKeyExists( arguments.row, arguments.key )
			&& !isNull( arguments.row[ arguments.key ] )
			&& len( arguments.row[ arguments.key ] );
	}

	private struct function nullableId( value ){
		return {
			value     : isNull( arguments.value ) ? "" : arguments.value,
			cfsqltype : "cf_sql_bigint",
			null      : isNull( arguments.value )
		};
	}

	private struct function nullableTimestamp( value ){
		return {
			value     : isNull( arguments.value ) ? "" : arguments.value,
			cfsqltype : "cf_sql_timestamp",
			null      : isNull( arguments.value )
		};
	}

}
