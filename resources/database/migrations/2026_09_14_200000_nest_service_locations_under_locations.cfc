/**
 * Hang Service Locations under Locations in the Will Creator primary menu,
 * and nest the page in the tree so the URL matches.
 *
 * Other tenants are untouched. Idempotent: skips if the page is already
 * under Locations or the menu item already exists.
 */
component {

	function up( schema, qb ){
		var options = arguments.schema.getDefaultOptions();
		var stamp   = now();
		var site    = queryExecute(
			"SELECT `id` FROM `sites` WHERE `slug` = :slug",
			{ slug : { value : "willcreator", cfsqltype : "cf_sql_varchar" } },
			options
		);

		if ( !site.recordCount ) {
			return;
		}

		var siteId = site.id[ 1 ];
		var pages = queryExecute(
			"
			SELECT `id`, `path`, `parent_id`
			FROM `pages`
			WHERE `site_id` = :siteId
			  AND `path` IN ( 'locations', 'service-locations', 'locations/service-locations' )
			",
			{ siteId : { value : siteId, cfsqltype : "cf_sql_integer" } },
			options
		);

		var byPath = {};
		for ( var p in pages ) {
			byPath[ p.path ] = p;
		}

		if ( !structKeyExists( byPath, "locations" ) ) {
			return;
		}

		if ( structKeyExists( byPath, "service-locations" ) && !structKeyExists( byPath, "locations/service-locations" ) ) {
			queryExecute(
				"
				UPDATE `pages`
				SET `parent_id`  = :parentId,
				    `path`       = 'locations/service-locations',
				    `sort_order` = 0,
				    `updated_at` = :updatedAt
				WHERE `id` = :pageId
				",
				{
					parentId  : { value : byPath[ "locations" ].id, cfsqltype : "cf_sql_integer" },
					updatedAt : { value : stamp, cfsqltype : "cf_sql_timestamp" },
					pageId    : { value : byPath[ "service-locations" ].id, cfsqltype : "cf_sql_integer" }
				},
				options
			);

			queryExecute(
				"
				INSERT INTO `site_redirects` ( `site_id`, `from_path`, `to_path`, `status_code`, `created_at`, `updated_at` )
				SELECT :siteId, 'service-locations', 'locations/service-locations', 301, :createdAt, :updatedAt
				WHERE NOT EXISTS (
					SELECT 1 FROM `site_redirects`
					WHERE `site_id` = :siteId AND `from_path` = 'service-locations'
				)
				",
				{
					siteId    : { value : siteId, cfsqltype : "cf_sql_integer" },
					createdAt : { value : stamp, cfsqltype : "cf_sql_timestamp" },
					updatedAt : { value : stamp, cfsqltype : "cf_sql_timestamp" }
				},
				options
			);

			byPath[ "locations/service-locations" ] = {
				"id" : byPath[ "service-locations" ].id
			};
		}

		if ( !structKeyExists( byPath, "locations/service-locations" ) ) {
			return;
		}

		var pageId = byPath[ "locations/service-locations" ].id;
		var menu = queryExecute(
			"SELECT `id` FROM `menus` WHERE `site_id` = :siteId AND `slug` = 'primary'",
			{ siteId : { value : siteId, cfsqltype : "cf_sql_integer" } },
			options
		);

		if ( !menu.recordCount ) {
			return;
		}

		var locationsItem = queryExecute(
			"
			SELECT `id` FROM `menu_items`
			WHERE `menu_id` = :menuId
			  AND `content_type` = 'pages.page'
			  AND `content_id` = :locationsPageId
			  AND `parent_id` IS NULL
			",
			{
				menuId          : { value : menu.id[ 1 ], cfsqltype : "cf_sql_integer" },
				locationsPageId : { value : byPath[ "locations" ].id, cfsqltype : "cf_sql_integer" }
			},
			options
		);

		if ( !locationsItem.recordCount ) {
			return;
		}

		var parentId = locationsItem.id[ 1 ];
		var existing = queryExecute(
			"
			SELECT `id` FROM `menu_items`
			WHERE `menu_id` = :menuId
			  AND `content_type` = 'pages.page'
			  AND `content_id` = :pageId
			",
			{
				menuId : { value : menu.id[ 1 ], cfsqltype : "cf_sql_integer" },
				pageId : { value : pageId, cfsqltype : "cf_sql_integer" }
			},
			options
		);

		if ( existing.recordCount ) {
			queryExecute(
				"
				UPDATE `menu_items`
				SET `parent_id`  = :parentId,
				    `label`      = 'Service Locations',
				    `sort_order` = 0,
				    `updated_at` = :updatedAt
				WHERE `id` = :itemId
				",
				{
					parentId  : { value : parentId, cfsqltype : "cf_sql_integer" },
					updatedAt : { value : stamp, cfsqltype : "cf_sql_timestamp" },
					itemId    : { value : existing.id[ 1 ], cfsqltype : "cf_sql_integer" }
				},
				options
			);
			return;
		}

		queryExecute(
			"
			UPDATE `menu_items`
			SET `sort_order` = `sort_order` + 1,
			    `updated_at` = :updatedAt
			WHERE `parent_id` = :parentId
			",
			{
				parentId  : { value : parentId, cfsqltype : "cf_sql_integer" },
				updatedAt : { value : stamp, cfsqltype : "cf_sql_timestamp" }
			},
			options
		);

		queryExecute(
			"
			INSERT INTO `menu_items` (
				`menu_id`, `site_id`, `parent_id`, `label`, `link_type`,
				`content_type`, `content_id`, `url`, `target`, `sort_order`,
				`created_at`, `updated_at`
			)
			VALUES (
				:menuId, :siteId, :parentId, 'Service Locations', 'content',
				'pages.page', :pageId, NULL, '', 0,
				:createdAt, :updatedAt
			)
			",
			{
				menuId    : { value : menu.id[ 1 ], cfsqltype : "cf_sql_integer" },
				siteId    : { value : siteId, cfsqltype : "cf_sql_integer" },
				parentId  : { value : parentId, cfsqltype : "cf_sql_integer" },
				pageId    : { value : pageId, cfsqltype : "cf_sql_integer" },
				createdAt : { value : stamp, cfsqltype : "cf_sql_timestamp" },
				updatedAt : { value : stamp, cfsqltype : "cf_sql_timestamp" }
			},
			options
		);
	}

	function down( schema, qb ){
		var options = arguments.schema.getDefaultOptions();
		var site    = queryExecute(
			"SELECT `id` FROM `sites` WHERE `slug` = :slug",
			{ slug : { value : "willcreator", cfsqltype : "cf_sql_varchar" } },
			options
		);

		if ( !site.recordCount ) {
			return;
		}

		var siteId = site.id[ 1 ];

		queryExecute(
			"
			DELETE mi FROM `menu_items` mi
			INNER JOIN `pages` p ON p.`id` = mi.`content_id`
			WHERE mi.`site_id` = :siteId
			  AND mi.`content_type` = 'pages.page'
			  AND p.`path` IN ( 'service-locations', 'locations/service-locations' )
			  AND mi.`label` = 'Service Locations'
			",
			{ siteId : { value : siteId, cfsqltype : "cf_sql_integer" } },
			options
		);

		queryExecute(
			"
			UPDATE `pages`
			SET `parent_id` = NULL,
			    `path` = 'service-locations',
			    `updated_at` = :updatedAt
			WHERE `site_id` = :siteId
			  AND `path` = 'locations/service-locations'
			",
			{
				siteId    : { value : siteId, cfsqltype : "cf_sql_integer" },
				updatedAt : { value : now(), cfsqltype : "cf_sql_timestamp" }
			},
			options
		);

		queryExecute(
			"
			DELETE FROM `site_redirects`
			WHERE `site_id` = :siteId
			  AND `from_path` = 'service-locations'
			  AND `to_path` = 'locations/service-locations'
			",
			{ siteId : { value : siteId, cfsqltype : "cf_sql_integer" } },
			options
		);
	}

}
