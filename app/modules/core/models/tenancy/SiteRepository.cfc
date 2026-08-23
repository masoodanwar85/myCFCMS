/**
 * Persistence for tenant sites.
 *
 * The repository is the only place that knows the `sites` table exists.
 * It speaks entities in and entities out, so the service layer above it can be
 * reused unchanged by server-rendered pages, the REST API and a later GraphQL layer.
 */
component singleton extends="core.models.persistence.BaseRepository" {

	variables.TABLE   = "sites";
	variables.COLUMNS = [
		"id",
		"name",
		"slug",
		"status",
		"timezone",
		"locale",
		"created_at",
		"updated_at"
	];

	/**
	 * Insert a new site and return it with its generated id.
	 *
	 * @site A populated, unsaved Site.
	 *
	 * @throws Tenancy.SlugAlreadyTaken when another site already uses the slug.
	 */
	core.models.tenancy.Site function create( required core.models.tenancy.Site site ){
		var stamp  = now();
		var result = "";

		try {
			result = variables.query
				.from( variables.TABLE )
				.insert( {
					"name"       : arguments.site.getName(),
					"slug"       : arguments.site.getSlug(),
					"status"     : arguments.site.getStatus(),
					"timezone"   : arguments.site.getTimezone(),
					"locale"     : arguments.site.getLocale(),
					"created_at" : { value : stamp, cfsqltype : "cf_sql_timestamp" },
					"updated_at" : { value : stamp, cfsqltype : "cf_sql_timestamp" }
				} );
		} catch ( any e ) {
			// Guards the race the pre-check in SiteService cannot cover.
			if ( !isUniqueViolation( e ) ) {
				rethrow;
			}
			throw(
				type    = "Tenancy.SlugAlreadyTaken",
				message = "The site slug [#arguments.site.getSlug()#] is already in use.",
				detail  = e.message
			);
		}

		arguments.site.setId( generatedKey( result, variables.TABLE ) );
		arguments.site.setCreatedAt( stamp );
		arguments.site.setUpdatedAt( stamp );

		return arguments.site;
	}

	/**
	 * Persist changes to an existing site.
	 */
	core.models.tenancy.Site function update( required core.models.tenancy.Site site ){
		var stamp = now();

		variables.query
			.from( variables.TABLE )
			.where( "id", arguments.site.getId() )
			.update( {
				"name"       : arguments.site.getName(),
				"slug"       : arguments.site.getSlug(),
				"status"     : arguments.site.getStatus(),
				"timezone"   : arguments.site.getTimezone(),
				"locale"     : arguments.site.getLocale(),
				"updated_at" : { value : stamp, cfsqltype : "cf_sql_timestamp" }
			} );

		arguments.site.setUpdatedAt( stamp );

		return arguments.site;
	}

	/**
	 * @return Site, or null when no site has that id.
	 */
	function findById( required numeric id ){
		return toSiteOrNull(
			variables.query
				.from( variables.TABLE )
				.select( variables.COLUMNS )
				.where( "id", arguments.id )
				.first()
		);
	}

	/**
	 * @return Site, or null when no site has that slug.
	 */
	function findBySlug( required string slug ){
		return toSiteOrNull(
			variables.query
				.from( variables.TABLE )
				.select( variables.COLUMNS )
				.where( "slug", arguments.slug )
				.first()
		);
	}

	boolean function existsBySlug( required string slug ){
		return variables.query
			.from( variables.TABLE )
			.where( "slug", arguments.slug )
			.exists();
	}

	/**
	 * The lookup behind tenant resolution.
	 *
	 * Both the domain and the site must be usable: an inactive domain, or a
	 * domain on an inactive site, resolves to nothing. That is what lets an
	 * operator take a client offline without deleting any data.
	 *
	 * @domain An already-normalised hostname.
	 *
	 * @return Site, or null.
	 */
	function findActiveByDomain( required string domain ){
		return toSiteOrNull(
			variables.query
				.from( "site_domains AS d" )
				.join( "sites AS s", "s.id", "d.site_id" )
				.select( variables.COLUMNS.map( ( c ) => "s.#c#" ) )
				.where( "d.domain", arguments.domain )
				.where( "d.is_active", 1 )
				.where( "s.status", "active" )
				.first()
		);
	}

	array function findAll(){
		return variables.query
			.from( variables.TABLE )
			.select( variables.COLUMNS )
			.orderBy( "name" )
			.get()
			.map( ( row ) => toSite( row ) );
	}

	/**
	 * Map a result row onto a Site entity.
	 */
	core.models.tenancy.Site function toSite( required struct row ){
		return wirebox
			.getInstance( "Site@core" )
			.setId( arguments.row.id )
			.setName( arguments.row.name )
			.setSlug( arguments.row.slug )
			.setStatus( arguments.row.status )
			.setTimezone( arguments.row.timezone )
			.setLocale( arguments.row.locale )
			.setCreatedAt( arguments.row.created_at )
			.setUpdatedAt( arguments.row.updated_at );
	}

	private function toSiteOrNull( required struct row ){
		if ( arguments.row.isEmpty() ) {
			return;
		}
		return toSite( arguments.row );
	}

}
