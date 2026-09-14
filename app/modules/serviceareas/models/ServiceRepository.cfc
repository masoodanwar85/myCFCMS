/**
 * Persistence for `services`, scoped per site.
 */
component singleton extends="core.models.persistence.BaseRepository" {

	variables.TABLE   = "services";
	variables.COLUMNS = [
		"id", "site_id", "name", "slug", "href", "sort_order", "active", "created_at", "updated_at"
	];

	/**
	 * @throws ServiceAreas.ServiceSlugExists
	 */
	serviceareas.models.Service function create( required serviceareas.models.Service service ){
		var stamp  = now();
		var result = "";

		try {
			result = variables.query
				.from( variables.TABLE )
				.insert( {
					"site_id"    : arguments.service.getSiteId(),
					"name"       : arguments.service.getName(),
					"slug"       : arguments.service.getSlug(),
					"href"       : arguments.service.getHref() ?: "",
					"sort_order" : val( arguments.service.getSortOrder() ),
					"active"     : arguments.service.getActive() ? 1 : 0,
					"created_at" : { value : stamp, cfsqltype : "cf_sql_timestamp" },
					"updated_at" : { value : stamp, cfsqltype : "cf_sql_timestamp" }
				} );
		} catch ( any e ) {
			if ( !isUniqueViolation( e ) ) {
				rethrow;
			}
			throw(
				type    = "ServiceAreas.ServiceSlugExists",
				message = "This site already has a service [#arguments.service.getSlug()#].",
				detail  = e.message
			);
		}

		arguments.service.setId( generatedKey( result, variables.TABLE ) );
		arguments.service.setCreatedAt( stamp );
		arguments.service.setUpdatedAt( stamp );

		return arguments.service;
	}

	serviceareas.models.Service function update( required serviceareas.models.Service service ){
		var stamp = now();

		try {
			variables.query
				.from( variables.TABLE )
				.where( "id", arguments.service.getId() )
				.update( {
					"name"       : arguments.service.getName(),
					"slug"       : arguments.service.getSlug(),
					"href"       : arguments.service.getHref() ?: "",
					"sort_order" : val( arguments.service.getSortOrder() ),
					"active"     : arguments.service.getActive() ? 1 : 0,
					"updated_at" : { value : stamp, cfsqltype : "cf_sql_timestamp" }
				} );
		} catch ( any e ) {
			if ( !isUniqueViolation( e ) ) {
				rethrow;
			}
			throw(
				type    = "ServiceAreas.ServiceSlugExists",
				message = "This site already has a service [#arguments.service.getSlug()#].",
				detail  = e.message
			);
		}

		arguments.service.setUpdatedAt( stamp );

		return arguments.service;
	}

	function findById( required numeric id ){
		return toServiceOrNull( baseQuery().where( "id", arguments.id ).first() );
	}

	function findBySlug( required numeric siteId, required string slug ){
		return toServiceOrNull(
			baseQuery().where( "site_id", arguments.siteId ).where( "slug", arguments.slug ).first()
		);
	}

	array function findBySiteId( required numeric siteId ){
		return baseQuery()
			.where( "site_id", arguments.siteId )
			.orderBy( "sort_order" )
			.orderBy( "name" )
			.get()
			.map( ( row ) => toService( row ) );
	}

	array function findWithLocationCounts( required numeric siteId ){
		var counts = {};

		variables.query
			.from( "services_locations" )
			.select( [ "service_id" ] )
			.selectRaw( "COUNT(*) AS total" )
			.where( "site_id", arguments.siteId )
			.groupBy( "service_id" )
			.get()
			.each( ( row ) => {
				counts[ row.service_id ] = row.total;
			} );

		return findBySiteId( arguments.siteId ).map( ( service ) => {
			return service.setLocationCount( counts[ service.getId() ] ?: 0 );
		} );
	}

	array function findLocationIds( required numeric serviceId ){
		return variables.query
			.from( "services_locations" )
			.select( [ "location_id" ] )
			.where( "service_id", arguments.serviceId )
			.get()
			.map( ( row ) => val( row.location_id ) );
	}

	function replaceLocations(
		required numeric siteId,
		required numeric serviceId,
		required array locationIds,
		struct hrefByLocationId = {}
	){
		var existing = {};

		variables.query
			.from( "services_locations" )
			.select( [ "location_id", "href" ] )
			.where( "service_id", arguments.serviceId )
			.get()
			.each( ( row ) => {
				existing[ val( row.location_id ) ] = row.href ?: "";
			} );

		variables.query
			.from( "services_locations" )
			.where( "service_id", arguments.serviceId )
			.delete();

		for ( var locationId in arguments.locationIds ) {
			var id = val( locationId );
			if ( !id ) {
				continue;
			}
			var href = existing[ id ] ?: "";
			if ( !len( trim( href ) ) ) {
				href = arguments.hrefByLocationId[ id ] ?: ( arguments.hrefByLocationId[ toString( id ) ] ?: "" );
			}
			variables.query
				.from( "services_locations" )
				.insert( {
					"service_id"  : arguments.serviceId,
					"location_id" : id,
					"site_id"     : arguments.siteId,
					"href"        : href
				} );
		}

		return this;
	}

	function delete( required numeric serviceId ){
		variables.query.from( variables.TABLE ).where( "id", arguments.serviceId ).delete();
		return this;
	}

	array function findPanelsForSite( required numeric siteId ){
		var rows = variables.query
			.from( "services AS s" )
			.join( "services_locations AS sl", "sl.service_id", "s.id" )
			.join( "locations AS l", "l.id", "sl.location_id" )
			.selectRaw( "
				s.id AS service_id,
				s.name AS service_name,
				s.slug AS service_slug,
				s.href AS service_href,
				s.sort_order AS service_sort,
				l.id AS location_id,
				l.name AS location_name,
				l.region AS location_region,
				l.href AS location_href,
				sl.href AS pairing_href
			" )
			.where( "s.site_id", arguments.siteId )
			.where( "sl.site_id", arguments.siteId )
			.where( "l.site_id", arguments.siteId )
			.where( "s.active", 1 )
			.where( "l.active", 1 )
			.orderBy( "s.sort_order" )
			.orderBy( "s.name" )
			.orderBy( "l.name" )
			.get();

		var panels = [];
		var index  = {};

		for ( var row in rows ) {
			var key = toString( row.service_id );
			if ( !structKeyExists( index, key ) ) {
				var panel = {
					"slug"   : row.service_slug,
					"title"  : row.service_name,
					"href"   : row.service_href ?: "",
					"places" : []
				};
				arrayAppend( panels, panel );
				index[ key ] = panel;
			}
			var pairing  = trim( row.pairing_href ?: "" );
			var fallback = trim( row.location_href ?: "" );
			var svcHref  = trim( row.service_href ?: "" );
			arrayAppend( index[ key ].places, {
				"label"  : row.location_name,
				"region" : row.location_region ?: "",
				"href"   : len( pairing ) ? pairing : ( len( fallback ) ? fallback : svcHref )
			} );
		}

		return panels;
	}

	serviceareas.models.Service function toService( required struct row ){
		return wirebox
			.getInstance( "Service@serviceareas" )
			.setId( arguments.row.id )
			.setSiteId( arguments.row.site_id )
			.setName( arguments.row.name )
			.setSlug( arguments.row.slug )
			.setHref( arguments.row.href ?: "" )
			.setSortOrder( val( arguments.row.sort_order ) )
			.setActive( val( arguments.row.active ) ? true : false )
			.setCreatedAt( arguments.row.created_at )
			.setUpdatedAt( arguments.row.updated_at );
	}

	private function baseQuery(){
		return variables.query.from( variables.TABLE ).select( variables.COLUMNS );
	}

	private function toServiceOrNull( required struct row ){
		if ( arguments.row.isEmpty() ) {
			return;
		}
		return toService( arguments.row );
	}

}
