/**
 * Group 3 — the Pages module's table.
 *
 * Lives in the shared migrations directory like every other, but the table
 * belongs to the Pages module: Core does not read it, and no other feature
 * module may either.
 *
 * Two shape decisions worth stating up front:
 *
 *   1. Pages form a tree via `parent_id`, because a site's structure is a tree
 *      and menus, breadcrumbs and URLs all read it as one.
 *   2. Each page also stores its full `path` ("about/team"). Resolving a URL is
 *      then a single unique-index read rather than a walk up the tree on every
 *      request. The cost is that a rename or a move has to rewrite the paths of
 *      that page's descendants — PageService owns that, and the specs pin it.
 *
 * Requires MySQL 8.0.16+ for the enforced CHECK.
 */
component {

	function up( schema, qb ){
		var options = arguments.schema.getDefaultOptions();

		queryExecute(
			"
			CREATE TABLE `pages` (
				`id`               BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
				`site_id`          BIGINT UNSIGNED NOT NULL,
				`parent_id`        BIGINT UNSIGNED NULL,
				`title`            VARCHAR(255)    NOT NULL,
				`slug`             VARCHAR(191)    NOT NULL,
				`path`             VARCHAR(500)    NOT NULL,
				`status`           VARCHAR(20)     NOT NULL DEFAULT 'draft',
				`content`          MEDIUMTEXT      NULL,
				`meta_title`       VARCHAR(255)    NULL,
				`meta_description` VARCHAR(500)    NULL,
				`sort_order`       INT             NOT NULL DEFAULT 0,
				`published_at`     DATETIME        NULL,
				`created_by`       BIGINT UNSIGNED NULL,
				`updated_by`       BIGINT UNSIGNED NULL,
				`created_at`       DATETIME        NOT NULL,
				`updated_at`       DATETIME        NOT NULL,
				PRIMARY KEY (`id`),

				-- The routing key, and the reason sibling slugs cannot collide:
				-- two siblings sharing a slug would produce the same path.
				UNIQUE KEY `uq_pages_site_path` (`site_id`, `path`),

				-- Listing a parent's children in menu order.
				KEY `idx_pages_site_parent_sort` (`site_id`, `parent_id`, `sort_order`),

				-- Listing everything published on a site.
				KEY `idx_pages_site_status` (`site_id`, `status`),

				KEY `idx_pages_created_by` (`created_by`),
				KEY `idx_pages_updated_by` (`updated_by`),

				CONSTRAINT `ck_pages_status`
					CHECK (`status` IN ('draft','published','archived')),

				CONSTRAINT `fk_pages_site`
					FOREIGN KEY (`site_id`) REFERENCES `sites` (`id`)
					ON DELETE CASCADE
					ON UPDATE CASCADE,

				-- Deleting a page removes its subtree, so the tree can never be
				-- left with orphans pointing at a parent that is gone. The
				-- service still refuses a destructive delete unless the caller
				-- asks for it explicitly — see PageService.deletePage.
				CONSTRAINT `fk_pages_parent`
					FOREIGN KEY (`parent_id`) REFERENCES `pages` (`id`)
					ON DELETE CASCADE,

				-- Authorship survives the author: removing a user must not
				-- remove their pages, so these null out instead of cascading.
				-- A plain reference to `users.id` rather than a composite
				-- (id, site_id) key, because a platform super admin belongs to
				-- no site and must still be recordable as an author.
				CONSTRAINT `fk_pages_created_by`
					FOREIGN KEY (`created_by`) REFERENCES `users` (`id`)
					ON DELETE SET NULL,

				CONSTRAINT `fk_pages_updated_by`
					FOREIGN KEY (`updated_by`) REFERENCES `users` (`id`)
					ON DELETE SET NULL
			) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
			",
			{},
			options
		);
	}

	function down( schema, qb ){
		queryExecute( "DROP TABLE IF EXISTS `pages`", {}, arguments.schema.getDefaultOptions() );
	}

}
