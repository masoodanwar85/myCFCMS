/**
 * Group 2 — identity and access: users, roles, permissions.
 *
 * Shape follows the two decisions taken for this group:
 *
 *   1. A user belongs to exactly one site. The single exception is the platform
 *      super admin, who belongs to none and reaches all of them.
 *   2. Roles are defined per site, so each client can shape its own. Permissions
 *      are a global catalogue, because they describe what the *code* can do and
 *      are registered by Core and by feature modules, not by clients.
 *
 * Raw DDL for the same reason as Group 1: engine, charset, composite foreign
 * keys and functional indexes are the point here, and qb's schema builder emits
 * none of them.
 *
 * Requires MySQL 8.0.13+ (functional index) and 8.0.16+ (enforced CHECK).
 */
component {

	function up( schema, qb ){
		var options = arguments.schema.getDefaultOptions();

		/**
		 * A person who can sign in.
		 *
		 * Tenancy is encoded structurally: `site_id IS NULL` *is* the platform
		 * super admin, and any other row belongs to exactly one site. There is
		 * deliberately no separate `is_super_admin` flag, because a flag and a
		 * `site_id` can contradict each other — and the contradictory row is
		 * precisely the one that would slip past every site-scoped check. With
		 * one column carrying the fact, the bad state cannot be represented.
		 *
		 * A CHECK constraint reconciling a flag against `site_id` was the first
		 * design, but MySQL refuses a CHECK on a column that also carries a
		 * foreign key referential action, and keeping `ON DELETE CASCADE`
		 * consistent with Group 1 matters more than the flag did.
		 *
		 * `uq_users_scope_email` makes email unique *within* a tenant rather
		 * than globally, because two unrelated clients may legitimately have a
		 * user at the same address. `COALESCE(site_id, 0)` is a functional key
		 * part so that super admins — whose `site_id` is NULL — still collide
		 * with each other; a plain `(site_id, email)` index would not, since
		 * MySQL never treats two NULLs as equal.
		 *
		 * `uq_users_id_site` exists only to be the target of a composite
		 * foreign key from `user_roles`. See that table for why.
		 */
		queryExecute(
			"
			CREATE TABLE `users` (
				`id`            BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
				`site_id`       BIGINT UNSIGNED NULL,
				`name`          VARCHAR(150)    NOT NULL,
				`email`         VARCHAR(191)    NOT NULL,
				`password_hash` VARCHAR(255)    NOT NULL,
				`status`        VARCHAR(20)     NOT NULL DEFAULT 'active',
				`created_at`    DATETIME        NOT NULL,
				`updated_at`    DATETIME        NOT NULL,
				PRIMARY KEY (`id`),
				UNIQUE KEY `uq_users_scope_email` ( ( COALESCE(`site_id`, 0) ), `email` ),
				UNIQUE KEY `uq_users_id_site` (`id`, `site_id`),
				KEY `idx_users_site_id` (`site_id`),
				KEY `idx_users_status` (`status`),
				CONSTRAINT `ck_users_status` CHECK (`status` IN ('active','inactive')),
				CONSTRAINT `fk_users_site`
					FOREIGN KEY (`site_id`) REFERENCES `sites` (`id`)
					ON DELETE CASCADE
					ON UPDATE CASCADE
			) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
			",
			{},
			options
		);

		/**
		 * A named bundle of permissions, owned by one site.
		 *
		 * `uq_roles_id_site` is, again, a composite foreign key target.
		 */
		queryExecute(
			"
			CREATE TABLE `roles` (
				`id`          BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
				`site_id`     BIGINT UNSIGNED NOT NULL,
				`name`        VARCHAR(100)    NOT NULL,
				`slug`        VARCHAR(100)    NOT NULL,
				`description` VARCHAR(255)    NULL,
				`created_at`  DATETIME        NOT NULL,
				`updated_at`  DATETIME        NOT NULL,
				PRIMARY KEY (`id`),
				UNIQUE KEY `uq_roles_site_slug` (`site_id`, `slug`),
				UNIQUE KEY `uq_roles_id_site` (`id`, `site_id`),
				CONSTRAINT `fk_roles_site`
					FOREIGN KEY (`site_id`) REFERENCES `sites` (`id`)
					ON DELETE CASCADE
					ON UPDATE CASCADE
			) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
			",
			{},
			options
		);

		/**
		 * The catalogue of things the software can do.
		 *
		 * Global, and deliberately not site-scoped: a permission such as
		 * `pages.publish` is defined by the Pages module's code, not by a
		 * client. Clients compose these into their own roles instead.
		 */
		queryExecute(
			"
			CREATE TABLE `permissions` (
				`id`          BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
				`slug`        VARCHAR(100)    NOT NULL,
				`name`        VARCHAR(150)    NOT NULL,
				`description` VARCHAR(255)    NULL,
				`created_at`  DATETIME        NOT NULL,
				`updated_at`  DATETIME        NOT NULL,
				PRIMARY KEY (`id`),
				UNIQUE KEY `uq_permissions_slug` (`slug`)
			) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
			",
			{},
			options
		);

		/**
		 * Which permissions a role grants.
		 *
		 * The composite primary key is the uniqueness rule: a role cannot be
		 * granted the same permission twice, so granting is idempotent.
		 */
		queryExecute(
			"
			CREATE TABLE `role_permissions` (
				`role_id`       BIGINT UNSIGNED NOT NULL,
				`permission_id` BIGINT UNSIGNED NOT NULL,
				`created_at`    DATETIME        NOT NULL,
				PRIMARY KEY (`role_id`, `permission_id`),
				KEY `idx_role_permissions_permission_id` (`permission_id`),
				CONSTRAINT `fk_role_permissions_role`
					FOREIGN KEY (`role_id`) REFERENCES `roles` (`id`)
					ON DELETE CASCADE
					ON UPDATE CASCADE,
				CONSTRAINT `fk_role_permissions_permission`
					FOREIGN KEY (`permission_id`) REFERENCES `permissions` (`id`)
					ON DELETE CASCADE
					ON UPDATE CASCADE
			) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
			",
			{},
			options
		);

		/**
		 * Which roles a user holds.
		 *
		 * `site_id` is carried here even though it is derivable, so that both
		 * foreign keys can be composite: the user must belong to that site AND
		 * the role must belong to that site. Assigning site A's role to site B's
		 * user therefore fails in the database, not merely in a service method
		 * someone might forget to call. In a shared-database tenancy model,
		 * cross-tenant privilege assignment is the single worst bug available,
		 * so it is worth one denormalised column to make it unrepresentable.
		 */
		queryExecute(
			"
			CREATE TABLE `user_roles` (
				`user_id`    BIGINT UNSIGNED NOT NULL,
				`role_id`    BIGINT UNSIGNED NOT NULL,
				`site_id`    BIGINT UNSIGNED NOT NULL,
				`created_at` DATETIME        NOT NULL,
				PRIMARY KEY (`user_id`, `role_id`),
				KEY `idx_user_roles_role_id` (`role_id`),
				KEY `idx_user_roles_site_id` (`site_id`),
				CONSTRAINT `fk_user_roles_user`
					FOREIGN KEY (`user_id`, `site_id`) REFERENCES `users` (`id`, `site_id`)
					ON DELETE CASCADE
					ON UPDATE CASCADE,
				CONSTRAINT `fk_user_roles_role`
					FOREIGN KEY (`role_id`, `site_id`) REFERENCES `roles` (`id`, `site_id`)
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

		// Join tables first, then the tables they reference.
		queryExecute( "DROP TABLE IF EXISTS `user_roles`", {}, options );
		queryExecute( "DROP TABLE IF EXISTS `role_permissions`", {}, options );
		queryExecute( "DROP TABLE IF EXISTS `permissions`", {}, options );
		queryExecute( "DROP TABLE IF EXISTS `roles`", {}, options );
		queryExecute( "DROP TABLE IF EXISTS `users`", {}, options );
	}

}
