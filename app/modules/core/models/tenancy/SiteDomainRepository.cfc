/**
 * Persistence for the hostnames that map onto a site.
 *
 * Exclusive ownership of a hostname is enforced by a unique index in the
 * database. This repository surfaces that collision as a typed error rather
 * than letting a raw driver exception escape.
 */
component singleton extends="core.models.persistence.BaseRepository" {

	variables.TABLE   = "site_domains";
	variables.COLUMNS = [
		"id",
		"site_id",
		"domain",
		"is_primary",
		"is_active",
		"created_at",
		"updated_at"
	];

	/**
	 * Attach a hostname to a site.
	 *
	 * @siteDomain A populated, unsaved SiteDomain carrying an already-normalised domain.
	 *
	 * @throws Tenancy.DomainAlreadyAssigned when the hostname belongs to any site.
	 */
	core.models.tenancy.SiteDomain function create( required core.models.tenancy.SiteDomain siteDomain ){
		var stamp  = now();
		var result = "";

		try {
			result = variables.query
				.from( variables.TABLE )
				.insert( {
					"site_id"    : arguments.siteDomain.getSiteId(),
					"domain"     : arguments.siteDomain.getDomain(),
					"is_primary" : arguments.siteDomain.getIsPrimary() ? 1 : 0,
					"is_active"  : arguments.siteDomain.getIsActive() ? 1 : 0,
					"created_at" : { value : stamp, cfsqltype : "cf_sql_timestamp" },
					"updated_at" : { value : stamp, cfsqltype : "cf_sql_timestamp" }
				} );
		} catch ( any e ) {
			// Guards the race the pre-check in SiteService cannot cover.
			if ( !isUniqueViolation( e ) ) {
				rethrow;
			}
			throw(
				type    = "Tenancy.DomainAlreadyAssigned",
				message = "The domain [#arguments.siteDomain.getDomain()#] is already assigned to a site.",
				detail  = "A domain may belong to exactly one site. #e.message#"
			);
		}

		arguments.siteDomain.setId( generatedKey( result, variables.TABLE ) );
		arguments.siteDomain.setCreatedAt( stamp );
		arguments.siteDomain.setUpdatedAt( stamp );

		return arguments.siteDomain;
	}

	/**
	 * @return SiteDomain, or null when the hostname is not registered.
	 */
	function findByDomain( required string domain ){
		return toDomainOrNull(
			variables.query
				.from( variables.TABLE )
				.select( variables.COLUMNS )
				.where( "domain", arguments.domain )
				.first()
		);
	}

	boolean function existsByDomain( required string domain ){
		return variables.query
			.from( variables.TABLE )
			.where( "domain", arguments.domain )
			.exists();
	}

	array function findBySiteId( required numeric siteId ){
		return variables.query
			.from( variables.TABLE )
			.select( variables.COLUMNS )
			.where( "site_id", arguments.siteId )
			.orderBy( "is_primary", "desc" )
			.orderBy( "domain" )
			.get()
			.map( ( row ) => toDomain( row ) );
	}

	/**
	 * @return The site's primary SiteDomain, or null when none is marked primary.
	 */
	function findPrimaryForSite( required numeric siteId ){
		return toDomainOrNull(
			variables.query
				.from( variables.TABLE )
				.select( variables.COLUMNS )
				.where( "site_id", arguments.siteId )
				.where( "is_primary", 1 )
				.first()
		);
	}

	/**
	 * Make one domain the site's primary, demoting whichever currently holds it.
	 *
	 * Demote first: the database permits only one primary row per site, so the
	 * reverse order would collide with the unique index.
	 */
	function makePrimary( required numeric siteId, required numeric domainId ){
		var stamp = now();

		variables.query
			.from( variables.TABLE )
			.where( "site_id", arguments.siteId )
			.where( "id", "!=", arguments.domainId )
			.update( {
				"is_primary" : 0,
				"updated_at" : { value : stamp, cfsqltype : "cf_sql_timestamp" }
			} );

		variables.query
			.from( variables.TABLE )
			.where( "id", arguments.domainId )
			.update( {
				"is_primary" : 1,
				"updated_at" : { value : stamp, cfsqltype : "cf_sql_timestamp" }
			} );

		return this;
	}

	/**
	 * Set or clear the primary flag on a single domain row.
	 *
	 * Lower level than `makePrimary`: the caller owns the ordering, which
	 * matters because only one row per site may hold the flag.
	 */
	function setPrimaryFlag( required numeric domainId, required boolean isPrimary ){
		variables.query
			.from( variables.TABLE )
			.where( "id", arguments.domainId )
			.update( {
				"is_primary" : arguments.isPrimary ? 1 : 0,
				"updated_at" : { value : now(), cfsqltype : "cf_sql_timestamp" }
			} );

		return this;
	}

	function setActive( required numeric domainId, required boolean isActive ){
		variables.query
			.from( variables.TABLE )
			.where( "id", arguments.domainId )
			.update( {
				"is_active"  : arguments.isActive ? 1 : 0,
				"updated_at" : { value : now(), cfsqltype : "cf_sql_timestamp" }
			} );

		return this;
	}

	function delete( required numeric domainId ){
		variables.query.from( variables.TABLE ).where( "id", arguments.domainId ).delete();
		return this;
	}

	core.models.tenancy.SiteDomain function toDomain( required struct row ){
		return wirebox
			.getInstance( "SiteDomain@core" )
			.setId( arguments.row.id )
			.setSiteId( arguments.row.site_id )
			.setDomain( arguments.row.domain )
			.setIsPrimary( arguments.row.is_primary ? true : false )
			.setIsActive( arguments.row.is_active ? true : false )
			.setCreatedAt( arguments.row.created_at )
			.setUpdatedAt( arguments.row.updated_at );
	}

	private function toDomainOrNull( required struct row ){
		if ( arguments.row.isEmpty() ) {
			return;
		}
		return toDomain( arguments.row );
	}

}
