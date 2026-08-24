/**
 * Editable navigation.
 *
 * Until now a site's menu was whatever the installed modules contributed:
 * Pages offered its top-level pages, Blog offered a "Blog" link. That is a
 * sensible default and a poor final answer — an editor could not reorder it,
 * rename an entry, group two links under one heading, or link to anything
 * outside the CMS.
 *
 * A site may have several menus, because a header menu and a footer menu are
 * different lists of the same kind of thing. `slug` is how a theme asks for one
 * — `primary` is the one the bundled themes render.
 *
 * ## Why an item is not just a URL
 *
 * A menu item that links to a page stores **what it points at**, not where that
 * thing currently lives: `link_type = 'content'`, plus the owning module's
 * `content_type` and the row's `content_id`. Storing the URL would mean every
 * menu quietly breaking — or, at best, redirecting — the first time an editor
 * renamed a page. Resolving through the module keeps the link exact.
 *
 * `link_type = 'url'` is the escape hatch: an external address, a mailto:, or
 * anything the CMS does not own.
 *
 * Core never learns what `content_type` means. It hands the pair back to the
 * module that registered it, exactly as it does for routing and sitemaps.
 */
component {

	function up( schema, qb ){
		var options = arguments.schema.getDefaultOptions();

		queryExecute(
			"
			CREATE TABLE `menus` (
				`id`         BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
				`site_id`    BIGINT UNSIGNED NOT NULL,
				`name`       VARCHAR(100)    NOT NULL,
				`slug`       VARCHAR(100)    NOT NULL,
				`created_at` DATETIME        NOT NULL,
				`updated_at` DATETIME        NOT NULL,
				PRIMARY KEY (`id`),
				-- How a theme asks for a menu, so it must be unambiguous within
				-- a site — and free to repeat across sites, which is the whole
				-- point of every tenant having its own `primary`.
				UNIQUE KEY `uq_menus_site_slug` (`site_id`, `slug`),
				-- Referenced by the composite foreign key on menu_items below,
				-- which is what makes a cross-tenant item impossible rather
				-- than merely discouraged.
				UNIQUE KEY `uq_menus_id_site` (`id`, `site_id`),
				CONSTRAINT `fk_menus_site`
					FOREIGN KEY (`site_id`) REFERENCES `sites` (`id`)
					ON DELETE CASCADE ON UPDATE CASCADE
			) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
			",
			{},
			options
		);

		queryExecute(
			"
			CREATE TABLE `menu_items` (
				`id`           BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
				`menu_id`      BIGINT UNSIGNED NOT NULL,
				-- Denormalised from `menus` on purpose: it is what lets the
				-- composite foreign key below prove an item and its menu belong
				-- to the same tenant, the same way user_roles does.
				`site_id`      BIGINT UNSIGNED NOT NULL,
				`parent_id`    BIGINT UNSIGNED NULL,
				`label`        VARCHAR(150)    NOT NULL,
				-- 'content' -> content_type + content_id; 'url' -> url.
				`link_type`    VARCHAR(20)     NOT NULL DEFAULT 'url',
				`content_type` VARCHAR(100)    NULL,
				`content_id`   BIGINT UNSIGNED NULL,
				`url`          VARCHAR(500)    NULL,
				-- Only ever '' or '_blank'; a column rather than a flag so a
				-- theme can emit it without translating.
				`target`       VARCHAR(20)     NOT NULL DEFAULT '',
				`sort_order`   INT             NOT NULL DEFAULT 0,
				`created_at`   DATETIME        NOT NULL,
				`updated_at`   DATETIME        NOT NULL,
				PRIMARY KEY (`id`),
				KEY `idx_menu_items_menu_order` (`menu_id`, `parent_id`, `sort_order`),
				KEY `idx_menu_items_content` (`site_id`, `content_type`, `content_id`),
				CONSTRAINT `fk_menu_items_menu`
					FOREIGN KEY (`menu_id`, `site_id`) REFERENCES `menus` (`id`, `site_id`)
					ON DELETE CASCADE ON UPDATE CASCADE,
				CONSTRAINT `fk_menu_items_site`
					FOREIGN KEY (`site_id`) REFERENCES `sites` (`id`)
					ON DELETE CASCADE ON UPDATE CASCADE,
				-- Deleting a heading deletes what hung beneath it. The
				-- alternative — orphans promoted to the top level — puts links
				-- somewhere nobody chose to put them.
				CONSTRAINT `fk_menu_items_parent`
					FOREIGN KEY (`parent_id`) REFERENCES `menu_items` (`id`)
					ON DELETE CASCADE
			) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
			",
			{},
			options
		);
	}

	function down( schema, qb ){
		var options = arguments.schema.getDefaultOptions();

		queryExecute( "DROP TABLE IF EXISTS `menu_items`", {}, options );
		queryExecute( "DROP TABLE IF EXISTS `menus`", {}, options );
	}

}
