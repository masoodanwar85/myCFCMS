/**
 * Group 1 — multi-tenancy foundation: sites, site_domains, site_settings.
 *
 * Written as explicit DDL rather than through qb's SchemaBuilder because the
 * requirements here are MySQL-specific and worth stating outright: the storage
 * engine, the character set and collation, the foreign keys, and the functional
 * unique index that keeps exactly one primary domain per site. The schema
 * builder's MySQL grammar emits none of those, so it would silently leave them
 * to server defaults. This project targets MySQL only, so the trade-off costs
 * us nothing.
 *
 * Requires MySQL 8.0.13+ (functional index) and 8.0.16+ (enforced CHECK).
 */
component {

	function up( schema, qb ){
		var options = arguments.schema.getDefaultOptions();

		/**
		 * A tenant website.
		 *
		 * Only the columns Group 1 actually needs. Theme, SEO defaults, owner
		 * and plan all belong to later groups and to `site_settings`; adding
		 * them now would mean guessing at shapes we cannot yet verify.
		 */
		queryExecute(
			"
			CREATE TABLE `sites` (
				`id`         BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
				`name`       VARCHAR(150)    NOT NULL,
				`slug`       VARCHAR(100)    NOT NULL,
				`status`     VARCHAR(20)     NOT NULL DEFAULT 'active',
				`timezone`   VARCHAR(64)     NOT NULL DEFAULT 'UTC',
				`locale`     VARCHAR(20)     NOT NULL DEFAULT 'en_US',
				`created_at` DATETIME        NOT NULL,
				`updated_at` DATETIME        NOT NULL,
				PRIMARY KEY (`id`),
				UNIQUE KEY `uq_sites_slug` (`slug`),
				KEY `idx_sites_status` (`status`),
				CONSTRAINT `ck_sites_status` CHECK (`status` IN ('active','inactive'))
			) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
			",
			{},
			options
		);

		/**
		 * The hostnames that route to a site.
		 *
		 * `uq_site_domains_domain` is the constraint the whole tenancy model
		 * rests on: a hostname resolves to one site and no other, enforced by
		 * the database rather than by application code. It doubles as the index
		 * behind every request's domain lookup, so resolution is a single-row
		 * unique-key read.
		 *
		 * `uq_site_domains_primary` is a functional index over
		 * `CASE WHEN is_primary = 1 THEN site_id END`. Non-primary rows evaluate
		 * to NULL, and MySQL does not compare NULLs in a unique index, so a site
		 * may hold many secondary domains but only ever one primary.
		 */
		queryExecute(
			"
			CREATE TABLE `site_domains` (
				`id`         BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
				`site_id`    BIGINT UNSIGNED NOT NULL,
				`domain`     VARCHAR(255)    NOT NULL,
				`is_primary` TINYINT(1)      NOT NULL DEFAULT 0,
				`is_active`  TINYINT(1)      NOT NULL DEFAULT 1,
				`created_at` DATETIME        NOT NULL,
				`updated_at` DATETIME        NOT NULL,
				PRIMARY KEY (`id`),
				UNIQUE KEY `uq_site_domains_domain` (`domain`),
				UNIQUE KEY `uq_site_domains_primary` (
					( CASE WHEN `is_primary` = 1 THEN `site_id` END )
				),
				KEY `idx_site_domains_site_id` (`site_id`),
				CONSTRAINT `fk_site_domains_site`
					FOREIGN KEY (`site_id`) REFERENCES `sites` (`id`)
					ON DELETE CASCADE
					ON UPDATE CASCADE
			) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
			",
			{},
			options
		);

		/**
		 * Tenant-scoped configuration.
		 *
		 * Key/value rather than a wide table: settings differ per site and each
		 * new module brings its own, and widening a shared table for every
		 * toggle does not scale across the module set we are heading towards.
		 *
		 * `setting_key` is 191 characters so the composite unique index stays
		 * comfortably inside InnoDB's key-length limit under utf8mb4.
		 */
		queryExecute(
			"
			CREATE TABLE `site_settings` (
				`id`            BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
				`site_id`       BIGINT UNSIGNED NOT NULL,
				`setting_key`   VARCHAR(191)    NOT NULL,
				`setting_value` TEXT            NULL,
				`created_at`    DATETIME        NOT NULL,
				`updated_at`    DATETIME        NOT NULL,
				PRIMARY KEY (`id`),
				UNIQUE KEY `uq_site_settings_site_key` (`site_id`, `setting_key`),
				CONSTRAINT `fk_site_settings_site`
					FOREIGN KEY (`site_id`) REFERENCES `sites` (`id`)
					ON DELETE CASCADE
					ON UPDATE CASCADE
			) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
			",
			{},
			options
		);
	}

	function down( schema, qb ){
		var options = arguments.schema.getDefaultOptions();

		// Children first: both carry a foreign key onto `sites`.
		queryExecute( "DROP TABLE IF EXISTS `site_settings`", {}, options );
		queryExecute( "DROP TABLE IF EXISTS `site_domains`", {}, options );
		queryExecute( "DROP TABLE IF EXISTS `sites`", {}, options );
	}

}
