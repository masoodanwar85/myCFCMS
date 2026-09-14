/**
 * Persistence for `locations`, scoped per site.
 */
component singleton extends="core.models.persistence.BaseRepository" {

	variables.TABLE   = "locations";
	variables.COLUMNS = [
		"id", "site_id", "name", "slug", "region", "href", "sort_order", "active", "created_at", "updated_at"
	];

	/**
	 * @throws ServiceAreas.LocationSlugExists
	 */
	serviceareas.models.Location function create( required serviceareas.models.Location location ){
		var stamp  = now();
		var result = "";

		try {
			result = variables.query
				.from( variables.TABLE )
				.insert( {
					"site_id"    : arguments.location.getSiteId(),
					"name"       : arguments.location.getName(),
					"slug"       : arguments.location.getSlug(),
					"region"     : arguments.location.getRegion() ?: "",
					"href"       : arguments.location.getHref() ?: "",
					"sort_order" : val( arguments.location.getSortOrder() ),
					"active"     : arguments.location.getActive() ? 1 : 0,
					"created_at" : { value : stamp, cfsqltype : "cf_sql_timestamp" },
					"updated_at" : { value : stamp, cfsqltype : "cf_sql_timestamp" }
				} );
		} catch ( any e ) {
			if ( !isUniqueViolation( e ) ) {
				rethrow;
			}
			throw(
				type    = "ServiceAreas.LocationSlugExists",
				message = "This site already has a location [#arguments.location.getSlug()#].",
				detail  = e.message
			);
		}

		arguments.location.setId( generatedKey( result, variables.TABLE ) );
		arguments.location.setCreatedAt( stamp );
		arguments.location.setUpdatedAt( stamp );

		return arguments.location;
	}

	serviceareas.models.Location function update( required serviceareas.models.Location location ){
		var stamp = now();

		try {
			variables.query
				.from( variables.TABLE )
				.where( "id", arguments.location.getId() )
				.update( {
					"name"       : arguments.location.getName(),
					"slug"       : arguments.location.getSlug(),
					"region"     : arguments.location.getRegion() ?: "",
					"href"       : arguments.location.getHref() ?: "",
					"sort_order" : val( arguments.location.getSortOrder() ),
					"active"     : arguments.location.getActive() ? 1 : 0,
					"updated_at" : { value : stamp, cfsqltype : "cf_sql_timestamp" }
				} );
		} catch ( any e ) {
			if ( !isUniqueViolation( e ) ) {
				rethrow;
			}
			throw(
				type    = "ServiceAreas.LocationSlugExists",
				message = "This site already has a location [#arguments.location.getSlug()#].",
				detail  = e.message
			);
		}

		arguments.location.setUpdatedAt( stamp );

		return arguments.location;
	}

	function findById( required numeric id ){
		return toLocationOrNull( baseQuery().where( "id", arguments.id ).first() );
	}

	function findBySlug( required numeric siteId, required string slug ){
		return toLocationOrNull(
			baseQuery().where( "site_id", arguments.siteId ).where( "slug", arguments.slug ).first()
		);
	}

	array function findBySiteId( required numeric siteId ){
		return baseQuery()
			.where( "site_id", arguments.siteId )
			.orderBy( "name" )
			.get()
			.map( ( row ) => toLocation( row ) );
	}

	function delete( required numeric locationId ){
		variables.query.from( variables.TABLE ).where( "id", arguments.locationId ).delete();
		return this;
	}

	serviceareas.models.Location function toLocation( required struct row ){
		return wirebox
			.getInstance( "Location@serviceareas" )
			.setId( arguments.row.id )
			.setSiteId( arguments.row.site_id )
			.setName( arguments.row.name )
			.setSlug( arguments.row.slug )
			.setRegion( arguments.row.region ?: "" )
			.setHref( arguments.row.href ?: "" )
			.setSortOrder( val( arguments.row.sort_order ) )
			.setActive( val( arguments.row.active ) ? true : false )
			.setCreatedAt( arguments.row.created_at )
			.setUpdatedAt( arguments.row.updated_at );
	}

	private function baseQuery(){
		return variables.query.from( variables.TABLE ).select( variables.COLUMNS );
	}

	private function toLocationOrNull( required struct row ){
		if ( arguments.row.isEmpty() ) {
			return;
		}
		return toLocation( arguments.row );
	}

}
