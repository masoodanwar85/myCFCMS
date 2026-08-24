/**
 * Persistence for blog categories, scoped per site.
 */
component singleton extends="core.models.persistence.BaseRepository" {

	variables.TABLE   = "blog_categories";
	variables.COLUMNS = [ "id", "site_id", "name", "slug", "description", "created_at", "updated_at" ];

	/**
	 * @throws Blog.CategorySlugExists
	 */
	blog.models.Category function create( required blog.models.Category category ){
		var stamp  = now();
		var result = "";

		try {
			result = variables.query
				.from( variables.TABLE )
				.insert( {
					"site_id"     : arguments.category.getSiteId(),
					"name"        : arguments.category.getName(),
					"slug"        : arguments.category.getSlug(),
					"description" : arguments.category.getDescription() ?: "",
					"created_at"  : { value : stamp, cfsqltype : "cf_sql_timestamp" },
					"updated_at"  : { value : stamp, cfsqltype : "cf_sql_timestamp" }
				} );
		} catch ( any e ) {
			if ( !isUniqueViolation( e ) ) {
				rethrow;
			}
			throw(
				type    = "Blog.CategorySlugExists",
				message = "This site already has a category [#arguments.category.getSlug()#].",
				detail  = e.message
			);
		}

		arguments.category.setId( generatedKey( result, variables.TABLE ) );
		arguments.category.setCreatedAt( stamp );
		arguments.category.setUpdatedAt( stamp );

		return arguments.category;
	}

	blog.models.Category function update( required blog.models.Category category ){
		var stamp = now();

		variables.query
			.from( variables.TABLE )
			.where( "id", arguments.category.getId() )
			.update( {
				"name"        : arguments.category.getName(),
				"description" : arguments.category.getDescription() ?: "",
				"updated_at"  : { value : stamp, cfsqltype : "cf_sql_timestamp" }
			} );

		arguments.category.setUpdatedAt( stamp );

		return arguments.category;
	}

	function findById( required numeric id ){
		return toCategoryOrNull( baseQuery().where( "id", arguments.id ).first() );
	}

	function findBySlug( required numeric siteId, required string slug ){
		return toCategoryOrNull(
			baseQuery().where( "site_id", arguments.siteId ).where( "slug", arguments.slug ).first()
		);
	}

	boolean function existsBySlug( required numeric siteId, required string slug ){
		return variables.query
			.from( variables.TABLE )
			.where( "site_id", arguments.siteId )
			.where( "slug", arguments.slug )
			.exists();
	}

	array function findBySiteId( required numeric siteId ){
		return baseQuery()
			.where( "site_id", arguments.siteId )
			.orderBy( "name" )
			.get()
			.map( ( row ) => toCategory( row ) );
	}

	array function findByIds( required array ids ){
		if ( arguments.ids.isEmpty() ) {
			return [];
		}

		return baseQuery()
			.whereIn( "id", arguments.ids )
			.orderBy( "name" )
			.get()
			.map( ( row ) => toCategory( row ) );
	}

	/**
	 * Categories with how many published posts each holds, for a sidebar.
	 *
	 * One grouped query rather than a count per category.
	 */
	array function findWithPublishedCounts( required numeric siteId ){
		var counts = {};

		variables.query
			.from( "blog_post_categories AS pc" )
			.join( "blog_posts AS p", "p.id", "pc.post_id" )
			.select( [ "pc.category_id" ] )
			.selectRaw( "COUNT(*) AS total" )
			.where( "p.site_id", arguments.siteId )
			.where( "p.status", "published" )
			.groupBy( "pc.category_id" )
			.get()
			.each( ( row ) => {
				counts[ row.category_id ] = row.total;
			} );

		return findBySiteId( arguments.siteId ).map( ( category ) => {
			return category.setPostCount( counts[ category.getId() ] ?: 0 );
		} );
	}

	function delete( required numeric categoryId ){
		variables.query.from( variables.TABLE ).where( "id", arguments.categoryId ).delete();
		return this;
	}

	blog.models.Category function toCategory( required struct row ){
		return wirebox
			.getInstance( "Category@blog" )
			.setId( arguments.row.id )
			.setSiteId( arguments.row.site_id )
			.setName( arguments.row.name )
			.setSlug( arguments.row.slug )
			.setDescription( arguments.row.description ?: "" )
			.setCreatedAt( arguments.row.created_at )
			.setUpdatedAt( arguments.row.updated_at );
	}

	private function baseQuery(){
		return variables.query.from( variables.TABLE ).select( variables.COLUMNS );
	}

	private function toCategoryOrNull( required struct row ){
		if ( arguments.row.isEmpty() ) {
			return;
		}
		return toCategory( arguments.row );
	}

}
