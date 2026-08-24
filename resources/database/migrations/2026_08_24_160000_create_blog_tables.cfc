/**
 * Group 6 — the Blog module's tables.
 *
 * Blog is the second feature module, and the point of building it is to find
 * out whether the seams from Groups 3-5 actually hold: a module should be able
 * to add public URLs, admin screens, navigation and permissions without a line
 * of Core changing. It does.
 *
 * Posts are a flat list ordered by date, deliberately unlike Pages' tree. A
 * blog's structure is chronological, and categories — not a hierarchy — are how
 * readers narrow it down.
 *
 * Requires MySQL 8.0.16+ for the enforced CHECK.
 */
component {

	function up( schema, qb ){
		var options = arguments.schema.getDefaultOptions();

		/**
		 * `uq_blog_posts_site_slug` is both the uniqueness rule and the lookup
		 * index behind `/blog/{slug}`.
		 *
		 * `idx_blog_posts_site_status_date` serves the archive listing, which is
		 * always "this site's published posts, newest first" — the one query the
		 * blog runs on every visit.
		 */
		queryExecute(
			"
			CREATE TABLE `blog_posts` (
				`id`               BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
				`site_id`          BIGINT UNSIGNED NOT NULL,
				`title`            VARCHAR(255)    NOT NULL,
				`slug`             VARCHAR(191)    NOT NULL,
				`excerpt`          VARCHAR(500)    NULL,
				`content`          MEDIUMTEXT      NULL,
				`status`           VARCHAR(20)     NOT NULL DEFAULT 'draft',
				`published_at`     DATETIME        NULL,
				`meta_title`       VARCHAR(255)    NULL,
				`meta_description` VARCHAR(500)    NULL,
				`author_id`        BIGINT UNSIGNED NULL,
				`created_at`       DATETIME        NOT NULL,
				`updated_at`       DATETIME        NOT NULL,
				PRIMARY KEY (`id`),
				UNIQUE KEY `uq_blog_posts_site_slug` (`site_id`, `slug`),
				-- Composite foreign key target for blog_post_categories.
				UNIQUE KEY `uq_blog_posts_id_site` (`id`, `site_id`),
				KEY `idx_blog_posts_site_status_date` (`site_id`, `status`, `published_at`),
				KEY `idx_blog_posts_author` (`author_id`),
				CONSTRAINT `ck_blog_posts_status`
					CHECK (`status` IN ('draft','published','archived')),
				CONSTRAINT `fk_blog_posts_site`
					FOREIGN KEY (`site_id`) REFERENCES `sites` (`id`)
					ON DELETE CASCADE ON UPDATE CASCADE,
				-- Authorship survives the author, as with pages.
				CONSTRAINT `fk_blog_posts_author`
					FOREIGN KEY (`author_id`) REFERENCES `users` (`id`)
					ON DELETE SET NULL
			) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
			",
			{},
			options
		);

		queryExecute(
			"
			CREATE TABLE `blog_categories` (
				`id`          BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
				`site_id`     BIGINT UNSIGNED NOT NULL,
				`name`        VARCHAR(100)    NOT NULL,
				`slug`        VARCHAR(191)    NOT NULL,
				`description` VARCHAR(255)    NULL,
				`created_at`  DATETIME        NOT NULL,
				`updated_at`  DATETIME        NOT NULL,
				PRIMARY KEY (`id`),
				UNIQUE KEY `uq_blog_categories_site_slug` (`site_id`, `slug`),
				-- Composite foreign key target, as in Group 2.
				UNIQUE KEY `uq_blog_categories_id_site` (`id`, `site_id`),
				CONSTRAINT `fk_blog_categories_site`
					FOREIGN KEY (`site_id`) REFERENCES `sites` (`id`)
					ON DELETE CASCADE ON UPDATE CASCADE
			) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
			",
			{},
			options
		);

		/**
		 * Which categories a post is filed under.
		 *
		 * `site_id` is carried here for the same reason as `user_roles` in
		 * Group 2: it lets both foreign keys be composite, so filing one site's
		 * post under another site's category is not merely refused by a service
		 * — it cannot be stored.
		 */
		queryExecute(
			"
			CREATE TABLE `blog_post_categories` (
				`post_id`     BIGINT UNSIGNED NOT NULL,
				`category_id` BIGINT UNSIGNED NOT NULL,
				`site_id`     BIGINT UNSIGNED NOT NULL,
				`created_at`  DATETIME        NOT NULL,
				PRIMARY KEY (`post_id`, `category_id`),
				KEY `idx_blog_post_categories_category` (`category_id`),
				KEY `fk_blog_post_categories_post` (`post_id`, `site_id`),
				KEY `fk_blog_post_categories_category` (`category_id`, `site_id`),
				CONSTRAINT `fk_blog_post_categories_post`
					FOREIGN KEY (`post_id`, `site_id`) REFERENCES `blog_posts` (`id`, `site_id`)
					ON DELETE CASCADE ON UPDATE CASCADE,
				CONSTRAINT `fk_blog_post_categories_category`
					FOREIGN KEY (`category_id`, `site_id`) REFERENCES `blog_categories` (`id`, `site_id`)
					ON DELETE CASCADE ON UPDATE CASCADE
			) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
			",
			{},
			options
		);
	}

	function down( schema, qb ){
		var options = arguments.schema.getDefaultOptions();

		queryExecute( "DROP TABLE IF EXISTS `blog_post_categories`", {}, options );
		queryExecute( "DROP TABLE IF EXISTS `blog_categories`", {}, options );
		queryExecute( "DROP TABLE IF EXISTS `blog_posts`", {}, options );
	}

}
