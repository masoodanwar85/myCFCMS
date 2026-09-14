/**
 * Service Locations widget data.
 *
 * The public Legal Services menu still comes from pages and menus. These
 * tables exist only so the Service Locations page can list services that have
 * towns attached, without parsing "{Service} - {Place}" page titles.
 *
 * `services_locations.href` is per pairing so Wills/Katoomba and
 * Probate/Katoomba can point at different pages.
 */
component {

	function up( schema, qb ){
		var options = arguments.schema.getDefaultOptions();

		queryExecute(
			"
			CREATE TABLE `services` (
				`id`          BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
				`site_id`     BIGINT UNSIGNED NOT NULL,
				`name`        VARCHAR(255)    NOT NULL,
				`slug`        VARCHAR(191)    NOT NULL,
				`href`        VARCHAR(500)    NULL,
				`sort_order`  INT             NOT NULL DEFAULT 0,
				`active`      TINYINT(1)      NOT NULL DEFAULT 1,
				`created_at`  DATETIME        NOT NULL,
				`updated_at`  DATETIME        NOT NULL,
				PRIMARY KEY (`id`),
				UNIQUE KEY `uq_services_site_slug` (`site_id`, `slug`),
				UNIQUE KEY `uq_services_id_site` (`id`, `site_id`),
				KEY `idx_services_site_sort` (`site_id`, `active`, `sort_order`),
				CONSTRAINT `fk_services_site`
					FOREIGN KEY (`site_id`) REFERENCES `sites` (`id`)
					ON DELETE CASCADE ON UPDATE CASCADE
			) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
			",
			{},
			options
		);

		queryExecute(
			"
			CREATE TABLE `locations` (
				`id`          BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
				`site_id`     BIGINT UNSIGNED NOT NULL,
				`name`        VARCHAR(255)    NOT NULL,
				`slug`        VARCHAR(191)    NOT NULL,
				`region`      VARCHAR(191)    NULL,
				`href`        VARCHAR(500)    NULL,
				`sort_order`  INT             NOT NULL DEFAULT 0,
				`active`      TINYINT(1)      NOT NULL DEFAULT 1,
				`created_at`  DATETIME        NOT NULL,
				`updated_at`  DATETIME        NOT NULL,
				PRIMARY KEY (`id`),
				UNIQUE KEY `uq_locations_site_slug` (`site_id`, `slug`),
				UNIQUE KEY `uq_locations_id_site` (`id`, `site_id`),
				KEY `idx_locations_site_sort` (`site_id`, `active`, `sort_order`),
				CONSTRAINT `fk_locations_site`
					FOREIGN KEY (`site_id`) REFERENCES `sites` (`id`)
					ON DELETE CASCADE ON UPDATE CASCADE
			) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
			",
			{},
			options
		);

		queryExecute(
			"
			CREATE TABLE `services_locations` (
				`service_id`  BIGINT UNSIGNED NOT NULL,
				`location_id` BIGINT UNSIGNED NOT NULL,
				`site_id`     BIGINT UNSIGNED NOT NULL,
				`href`        VARCHAR(500)    NULL,
				PRIMARY KEY (`service_id`, `location_id`),
				KEY `idx_services_locations_site` (`site_id`),
				CONSTRAINT `fk_services_locations_service`
					FOREIGN KEY (`service_id`, `site_id`)
					REFERENCES `services` (`id`, `site_id`)
					ON DELETE CASCADE ON UPDATE CASCADE,
				CONSTRAINT `fk_services_locations_location`
					FOREIGN KEY (`location_id`, `site_id`)
					REFERENCES `locations` (`id`, `site_id`)
					ON DELETE CASCADE ON UPDATE CASCADE,
				CONSTRAINT `fk_services_locations_site`
					FOREIGN KEY (`site_id`) REFERENCES `sites` (`id`)
					ON DELETE CASCADE ON UPDATE CASCADE
			) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
			",
			{},
			options
		);
	}

	function down( schema, qb ){
		var options = arguments.schema.getDefaultOptions();

		queryExecute( "DROP TABLE IF EXISTS `services_locations`", {}, options );
		queryExecute( "DROP TABLE IF EXISTS `locations`", {}, options );
		queryExecute( "DROP TABLE IF EXISTS `services`", {}, options );
	}

}
