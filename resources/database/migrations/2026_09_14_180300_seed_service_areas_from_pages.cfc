/**
 * Copy the current Legal Services / Locations page tree into the Service Areas
 * tables so the widget has real rows on first migrate.
 *
 * Does not touch menus or the Legal Services pages themselves. Only:
 *
 *   - grandchildren of /locations (suburb/town pages)
 *   - direct children of /legal-services (except how-it-works, creating-a-will)
 *   - join rows for leaf pages titled "{Service} - {Place}"
 *
 * A service with no such leaves is stored but will not appear on the frontend
 * until locations are attached in admin.
 */
component {

	variables.SKIP_SLUGS = "how-it-works,creating-a-will";

	function up( schema, qb ){
		var options = arguments.schema.getDefaultOptions();
		var stamp   = now();
		var sites   = queryExecute(
			"
			SELECT DISTINCT p.`site_id`
			FROM `pages` p
			WHERE p.`path` = 'legal-services'
			  AND p.`status` = 'published'
			",
			{},
			options
		);

		for ( var siteRow in sites ) {
			seedSite( siteRow.site_id, stamp, options );
		}
	}

	function down( schema, qb ){
		var options = arguments.schema.getDefaultOptions();

		queryExecute( "DELETE FROM `services_locations`", {}, options );
		queryExecute( "DELETE FROM `locations`", {}, options );
		queryExecute( "DELETE FROM `services`", {}, options );
	}

	private function seedSite( required numeric siteId, required date stamp, required struct options ){
		var pages = queryExecute(
			"
			SELECT `id`, `parent_id`, `title`, `slug`, `path`, `sort_order`
			FROM `pages`
			WHERE `site_id` = :siteId
			  AND `status` = 'published'
			",
			{ siteId : { value : arguments.siteId, cfsqltype : "cf_sql_integer" } },
			arguments.options
		);

		var byId     = {};
		var kids     = {};
		var byPath   = {};

		for ( var p in pages ) {
			byId[ p.id ]   = p;
			byPath[ p.path ] = p;
			var pid = val( p.parent_id ?: 0 );
			if ( pid ) {
				if ( !structKeyExists( kids, pid ) ) {
					kids[ pid ] = [];
				}
				arrayAppend( kids[ pid ], p );
			}
		}

		var regionTitles = {};
		if ( structKeyExists( byPath, "locations" ) ) {
			var locationsRoot = byPath[ "locations" ];
			var regions = structKeyExists( kids, locationsRoot.id ) ? kids[ locationsRoot.id ] : [];
			for ( var region in regions ) {
				regionTitles[ lCase( region.title ) ] = true;
			}
			var sort = 0;
			for ( var region in regions ) {
				var suburbs = structKeyExists( kids, region.id ) ? kids[ region.id ] : [];
				for ( var suburb in suburbs ) {
					if ( structKeyExists( kids, suburb.id ) ) {
						continue;
					}
					sort++;
					insertLocation(
						siteId  = arguments.siteId,
						name    = suburb.title,
						slug    = suburb.slug,
						region  = region.title,
						href    = "/" & suburb.path,
						sort    = val( suburb.sort_order ) ? val( suburb.sort_order ) : sort,
						stamp   = arguments.stamp,
						options = arguments.options
					);
				}
			}
		}

		if ( !structKeyExists( byPath, "legal-services" ) ) {
			return;
		}

		var legalRoot = byPath[ "legal-services" ];
		var legalKids = structKeyExists( kids, legalRoot.id ) ? kids[ legalRoot.id ] : [];
		var svcSort   = 0;

		for ( var child in legalKids ) {
			if ( listFindNoCase( variables.SKIP_SLUGS, child.slug ) ) {
				continue;
			}
			svcSort++;
			insertService(
				siteId  = arguments.siteId,
				name    = child.title,
				slug    = child.slug,
				href    = "/" & child.path,
				sort    = val( child.sort_order ) ? val( child.sort_order ) : svcSort,
				stamp   = arguments.stamp,
				options = arguments.options
			);
		}

		var services = queryExecute(
			"SELECT `id`, `name`, `slug` FROM `services` WHERE `site_id` = :siteId",
			{ siteId : { value : arguments.siteId, cfsqltype : "cf_sql_integer" } },
			arguments.options
		);

		for ( var svc in services ) {
			var prefix = svc.name & " - ";
			for ( var p in pages ) {
				if ( left( p.title, len( prefix ) ) != prefix ) {
					continue;
				}
				if ( structKeyExists( kids, p.id ) ) {
					continue;
				}
				var place = trim( mid( p.title, len( prefix ) + 1, 500 ) );
				if ( !len( place ) ) {
					continue;
				}
				if ( structKeyExists( regionTitles, lCase( place ) ) ) {
					continue;
				}
				var locationId = findOrCreateLocation(
					siteId  = arguments.siteId,
					name    = place,
					stamp   = arguments.stamp,
					options = arguments.options
				);
				insertJoin(
					siteId     = arguments.siteId,
					serviceId  = svc.id,
					locationId = locationId,
					href       = "/" & p.path,
					options    = arguments.options
				);
			}
		}
	}

	private function insertService(
		required numeric siteId,
		required string name,
		required string slug,
		required string href,
		required numeric sort,
		required date stamp,
		required struct options
	){
		queryExecute(
			"
			INSERT INTO `services` ( `site_id`, `name`, `slug`, `href`, `sort_order`, `active`, `created_at`, `updated_at` )
			SELECT :siteId, :name, :slug, :href, :sortOrder, 1, :createdAt, :updatedAt
			WHERE NOT EXISTS (
				SELECT 1 FROM `services` WHERE `site_id` = :siteId AND `slug` = :slug
			)
			",
			{
				siteId    : { value : arguments.siteId, cfsqltype : "cf_sql_integer" },
				name      : { value : arguments.name, cfsqltype : "cf_sql_varchar" },
				slug      : { value : arguments.slug, cfsqltype : "cf_sql_varchar" },
				href      : { value : arguments.href, cfsqltype : "cf_sql_varchar" },
				sortOrder : { value : arguments.sort, cfsqltype : "cf_sql_integer" },
				createdAt : { value : arguments.stamp, cfsqltype : "cf_sql_timestamp" },
				updatedAt : { value : arguments.stamp, cfsqltype : "cf_sql_timestamp" }
			},
			arguments.options
		);
	}

	private function insertLocation(
		required numeric siteId,
		required string name,
		required string slug,
		required string region,
		required string href,
		required numeric sort,
		required date stamp,
		required struct options
	){
		queryExecute(
			"
			INSERT INTO `locations` ( `site_id`, `name`, `slug`, `region`, `href`, `sort_order`, `active`, `created_at`, `updated_at` )
			SELECT :siteId, :name, :slug, :region, :href, :sortOrder, 1, :createdAt, :updatedAt
			WHERE NOT EXISTS (
				SELECT 1 FROM `locations` WHERE `site_id` = :siteId AND `slug` = :slug
			)
			",
			{
				siteId    : { value : arguments.siteId, cfsqltype : "cf_sql_integer" },
				name      : { value : arguments.name, cfsqltype : "cf_sql_varchar" },
				slug      : { value : arguments.slug, cfsqltype : "cf_sql_varchar" },
				region    : { value : arguments.region, cfsqltype : "cf_sql_varchar" },
				href      : { value : arguments.href, cfsqltype : "cf_sql_varchar" },
				sortOrder : { value : arguments.sort, cfsqltype : "cf_sql_integer" },
				createdAt : { value : arguments.stamp, cfsqltype : "cf_sql_timestamp" },
				updatedAt : { value : arguments.stamp, cfsqltype : "cf_sql_timestamp" }
			},
			arguments.options
		);
	}

	private numeric function findOrCreateLocation(
		required numeric siteId,
		required string name,
		required date stamp,
		required struct options
	){
		var existing = queryExecute(
			"
			SELECT `id` FROM `locations`
			WHERE `site_id` = :siteId
			  AND ( `name` = :name OR `slug` = :slug )
			LIMIT 1
			",
			{
				siteId : { value : arguments.siteId, cfsqltype : "cf_sql_integer" },
				name   : { value : arguments.name, cfsqltype : "cf_sql_varchar" },
				slug   : { value : slugify( arguments.name ), cfsqltype : "cf_sql_varchar" }
			},
			arguments.options
		);

		if ( existing.recordCount ) {
			return existing.id[ 1 ];
		}

		var slug = uniqueSlug( arguments.siteId, slugify( arguments.name ), arguments.options );

		queryExecute(
			"
			INSERT INTO `locations` ( `site_id`, `name`, `slug`, `region`, `href`, `sort_order`, `active`, `created_at`, `updated_at` )
			VALUES ( :siteId, :name, :slug, '', '', 0, 1, :createdAt, :updatedAt )
			",
			{
				siteId    : { value : arguments.siteId, cfsqltype : "cf_sql_integer" },
				name      : { value : arguments.name, cfsqltype : "cf_sql_varchar" },
				slug      : { value : slug, cfsqltype : "cf_sql_varchar" },
				createdAt : { value : arguments.stamp, cfsqltype : "cf_sql_timestamp" },
				updatedAt : { value : arguments.stamp, cfsqltype : "cf_sql_timestamp" }
			},
			arguments.options
		);

		var created = queryExecute(
			"SELECT `id` FROM `locations` WHERE `site_id` = :siteId AND `slug` = :slug",
			{
				siteId : { value : arguments.siteId, cfsqltype : "cf_sql_integer" },
				slug   : { value : slug, cfsqltype : "cf_sql_varchar" }
			},
			arguments.options
		);

		return created.id[ 1 ];
	}

	private function insertJoin(
		required numeric siteId,
		required numeric serviceId,
		required numeric locationId,
		required string href,
		required struct options
	){
		queryExecute(
			"
			INSERT INTO `services_locations` ( `service_id`, `location_id`, `site_id`, `href` )
			SELECT :serviceId, :locationId, :siteId, :href
			WHERE NOT EXISTS (
				SELECT 1 FROM `services_locations`
				WHERE `service_id` = :serviceId AND `location_id` = :locationId
			)
			",
			{
				siteId     : { value : arguments.siteId, cfsqltype : "cf_sql_integer" },
				serviceId  : { value : arguments.serviceId, cfsqltype : "cf_sql_integer" },
				locationId : { value : arguments.locationId, cfsqltype : "cf_sql_integer" },
				href       : { value : arguments.href, cfsqltype : "cf_sql_varchar" }
			},
			arguments.options
		);
	}

	private string function uniqueSlug( required numeric siteId, required string slug, required struct options ){
		var base = len( arguments.slug ) ? arguments.slug : "location";
		var trySlug = base;
		var n = 2;

		while ( true ) {
			var hit = queryExecute(
				"SELECT `id` FROM `locations` WHERE `site_id` = :siteId AND `slug` = :slug",
				{
					siteId : { value : arguments.siteId, cfsqltype : "cf_sql_integer" },
					slug   : { value : trySlug, cfsqltype : "cf_sql_varchar" }
				},
				arguments.options
			);
			if ( !hit.recordCount ) {
				return trySlug;
			}
			trySlug = base & "-" & n;
			n++;
		}
	}

	private string function slugify( required string value ){
		var s = lCase( trim( arguments.value ) );
		s = reReplace( s, "[^a-z0-9]+", "-", "all" );
		s = reReplace( s, "^-+|-+$", "", "all" );
		return left( s, 191 );
	}

}
