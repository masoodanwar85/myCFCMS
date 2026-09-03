/**
 * Persistence for blog posts and their categories.
 *
 * Every read is scoped by `site_id`. Categories are loaded on request rather
 * than always: a listing of twenty posts does not need each one's categories,
 * and fetching them anyway would be twenty extra queries.
 */
component singleton extends="core.models.persistence.BaseRepository" {

	variables.TABLE   = "blog_posts";
	variables.COLUMNS = [
		"id",
		"site_id",
		"title",
		"slug",
		"excerpt",
		"content",
		"show_heading",
		"status",
		"published_at",
		"meta_title",
		"meta_description",
		"author_id",
		"created_at",
		"updated_at"
	];

	/**
	 * @throws Blog.SlugAlreadyExists when the site already has a post at that slug.
	 */
	blog.models.Post function create( required blog.models.Post post ){
		var stamp  = now();
		var result = "";

		try {
			result = variables.query
				.from( variables.TABLE )
				.insert( {
					"site_id"          : arguments.post.getSiteId(),
					"title"            : arguments.post.getTitle(),
					"slug"             : arguments.post.getSlug(),
					"excerpt"          : arguments.post.getExcerpt() ?: "",
					"content"          : { value : arguments.post.getContent() ?: "", cfsqltype : "cf_sql_longvarchar" },
					// `null : false`: the column is NOT NULL with a default,
					// and qb infers a null bind from a falsy value.
					"show_heading"     : { value : arguments.post.getShowHeading() ? 1 : 0, cfsqltype : "cf_sql_tinyint", null : false },
					"status"           : arguments.post.getStatus(),
					"published_at"     : nullableTimestamp( arguments.post.getPublishedAt() ),
					"meta_title"       : arguments.post.getMetaTitle() ?: "",
					"meta_description" : arguments.post.getMetaDescription() ?: "",
					"author_id"        : nullableId( arguments.post.getAuthorId() ),
					"created_at"       : { value : stamp, cfsqltype : "cf_sql_timestamp" },
					"updated_at"       : { value : stamp, cfsqltype : "cf_sql_timestamp" }
				} );
		} catch ( any e ) {
			if ( !isUniqueViolation( e ) ) {
				rethrow;
			}
			throw(
				type    = "Blog.SlugAlreadyExists",
				message = "This site already has a post at [#arguments.post.getSlug()#].",
				detail  = e.message
			);
		}

		arguments.post.setId( generatedKey( result, variables.TABLE ) );
		arguments.post.setCreatedAt( stamp );
		arguments.post.setUpdatedAt( stamp );

		return arguments.post;
	}

	blog.models.Post function update( required blog.models.Post post ){
		var stamp = now();

		try {
			variables.query
				.from( variables.TABLE )
				.where( "id", arguments.post.getId() )
				.update( {
					"title"            : arguments.post.getTitle(),
					"slug"             : arguments.post.getSlug(),
					"excerpt"          : arguments.post.getExcerpt() ?: "",
					"content"          : { value : arguments.post.getContent() ?: "", cfsqltype : "cf_sql_longvarchar" },
					// `null : false`: the column is NOT NULL with a default,
					// and qb infers a null bind from a falsy value.
					"show_heading"     : { value : arguments.post.getShowHeading() ? 1 : 0, cfsqltype : "cf_sql_tinyint", null : false },
					"status"           : arguments.post.getStatus(),
					"published_at"     : nullableTimestamp( arguments.post.getPublishedAt() ),
					"meta_title"       : arguments.post.getMetaTitle() ?: "",
					"meta_description" : arguments.post.getMetaDescription() ?: "",
					"updated_at"       : { value : stamp, cfsqltype : "cf_sql_timestamp" }
				} );
		} catch ( any e ) {
			if ( !isUniqueViolation( e ) ) {
				rethrow;
			}
			throw(
				type    = "Blog.SlugAlreadyExists",
				message = "This site already has a post at [#arguments.post.getSlug()#].",
				detail  = e.message
			);
		}

		arguments.post.setUpdatedAt( stamp );

		return arguments.post;
	}

	function findById( required numeric id ){
		return toPostOrNull( baseQuery().where( "id", arguments.id ).first() );
	}

	function findBySlug( required numeric siteId, required string slug ){
		return toPostOrNull(
			baseQuery().where( "site_id", arguments.siteId ).where( "slug", arguments.slug ).first()
		);
	}

	/**
	 * The public lookup behind `/blog/{slug}`.
	 */
	function findPublishedBySlug( required numeric siteId, required string slug ){
		return toPostOrNull(
			baseQuery()
				.where( "site_id", arguments.siteId )
				.where( "slug", arguments.slug )
				.where( "status", "published" )
				.first()
		);
	}

	boolean function existsBySlug( required numeric siteId, required string slug ){
		return variables.query
			.from( variables.TABLE )
			.where( "site_id", arguments.siteId )
			.where( "slug", arguments.slug )
			.exists();
	}

	/**
	 * A site's posts, newest first. The editor's view: every status.
	 */
	array function findBySiteId(
		required numeric siteId,
		numeric limit  = 25,
		numeric offset = 0
	){
		return baseQuery()
			.where( "site_id", arguments.siteId )
			.orderBy( "created_at", "desc" )
			.orderBy( "id", "desc" )
			.limit( arguments.limit )
			.offset( arguments.offset )
			.get()
			.map( ( row ) => toPost( row ) );
	}

	numeric function countBySiteId( required numeric siteId ){
		return variables.query.from( variables.TABLE ).where( "site_id", arguments.siteId ).count();
	}

	/**
	 * The archive listing: published posts, newest first.
	 */
	array function findPublished(
		required numeric siteId,
		numeric limit  = 20,
		numeric offset = 0
	){
		return baseQuery()
			.where( "site_id", arguments.siteId )
			.where( "status", "published" )
			.orderBy( "published_at", "desc" )
			.orderBy( "id", "desc" )
			.limit( arguments.limit )
			.offset( arguments.offset )
			.get()
			.map( ( row ) => toPost( row ) );
	}

	numeric function countPublished( required numeric siteId ){
		return variables.query
			.from( variables.TABLE )
			.where( "site_id", arguments.siteId )
			.where( "status", "published" )
			.count();
	}

	/**
	 * Published posts filed under one category, newest first.
	 */
	array function findPublishedInCategory(
		required numeric siteId,
		required numeric categoryId,
		numeric limit  = 20,
		numeric offset = 0
	){
		return variables.query
			.from( "blog_posts AS p" )
			.join( "blog_post_categories AS pc", "pc.post_id", "p.id" )
			.select( variables.COLUMNS.map( ( c ) => "p.#c#" ) )
			.where( "p.site_id", arguments.siteId )
			.where( "p.status", "published" )
			.where( "pc.category_id", arguments.categoryId )
			.orderBy( "p.published_at", "desc" )
			.limit( arguments.limit )
			.offset( arguments.offset )
			.get()
			.map( ( row ) => toPost( row ) );
	}

	numeric function countPublishedInCategory( required numeric siteId, required numeric categoryId ){
		return variables.query
			.from( "blog_posts AS p" )
			.join( "blog_post_categories AS pc", "pc.post_id", "p.id" )
			.where( "p.site_id", arguments.siteId )
			.where( "p.status", "published" )
			.where( "pc.category_id", arguments.categoryId )
			.count();
	}

	function delete( required numeric postId ){
		variables.query.from( variables.TABLE ).where( "id", arguments.postId ).delete();
		return this;
	}

	/* ---------------------------------------------------------------------
	 * Post <-> category
	 * ------------------------------------------------------------------ */

	/**
	 * File a post under a category.
	 *
	 * `site_id` is written alongside so the composite foreign keys can check
	 * that both belong to the same site. A cross-tenant pairing is rejected by
	 * the database, not merely by this method.
	 *
	 * @throws Blog.CrossTenantCategory
	 */
	function addCategory(
		required numeric postId,
		required numeric categoryId,
		required numeric siteId
	){
		if ( hasCategory( arguments.postId, arguments.categoryId ) ) {
			return this;
		}

		try {
			variables.query
				.from( "blog_post_categories" )
				.insert( {
					"post_id"     : arguments.postId,
					"category_id" : arguments.categoryId,
					"site_id"     : arguments.siteId,
					"created_at"  : { value : now(), cfsqltype : "cf_sql_timestamp" }
				} );
		} catch ( any e ) {
			if ( isForeignKeyViolation( e ) ) {
				throw(
					type    = "Blog.CrossTenantCategory",
					message = "Post [#arguments.postId#] and category [#arguments.categoryId#] are not both on site [#arguments.siteId#].",
					detail  = e.message
				);
			}
			if ( !isUniqueViolation( e ) ) {
				rethrow;
			}
		}

		return this;
	}

	boolean function hasCategory( required numeric postId, required numeric categoryId ){
		return variables.query
			.from( "blog_post_categories" )
			.where( "post_id", arguments.postId )
			.where( "category_id", arguments.categoryId )
			.exists();
	}

	function clearCategories( required numeric postId ){
		variables.query.from( "blog_post_categories" ).where( "post_id", arguments.postId ).delete();
		return this;
	}

	array function findCategoryIdsForPost( required numeric postId ){
		return variables.query
			.from( "blog_post_categories" )
			.select( [ "category_id" ] )
			.where( "post_id", arguments.postId )
			.get()
			.map( ( row ) => row.category_id );
	}

	blog.models.Post function toPost( required struct row ){
		var post = wirebox
			.getInstance( "Post@blog" )
			.setId( arguments.row.id )
			.setSiteId( arguments.row.site_id )
			.setTitle( arguments.row.title )
			.setSlug( arguments.row.slug )
			.setExcerpt( arguments.row.excerpt ?: "" )
			.setContent( arguments.row.content ?: "" )
			.setShowHeading( arguments.row.show_heading ? true : false )
			.setStatus( arguments.row.status )
			.setMetaTitle( arguments.row.meta_title ?: "" )
			.setMetaDescription( arguments.row.meta_description ?: "" )
			.setCreatedAt( arguments.row.created_at )
			.setUpdatedAt( arguments.row.updated_at );

		if ( hasValue( arguments.row, "published_at" ) ) {
			post.setPublishedAt( arguments.row.published_at );
		}
		if ( hasValue( arguments.row, "author_id" ) ) {
			post.setAuthorId( arguments.row.author_id );
		}

		return post;
	}

	private function baseQuery(){
		return variables.query.from( variables.TABLE ).select( variables.COLUMNS );
	}

	private function toPostOrNull( required struct row ){
		if ( arguments.row.isEmpty() ) {
			return;
		}
		return toPost( arguments.row );
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
