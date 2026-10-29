/**
 * What changed through the API, who changed it, and what it looked like before.
 *
 * ## Why this table exists
 *
 * The API now hands a token the ability to write content, and the `agent` role
 * exists so an automated client can use it. An automated client making changes
 * nobody can reconstruct afterwards is the part of that which needs answering:
 * when a page's title is wrong on Monday, "which token did that, and what did
 * it say before" has to have an answer that does not depend on anybody having
 * watched.
 *
 * ## Why `api_change_log` and not `agent_change_log`
 *
 * Nothing in the API knows or cares whether the token belongs to an agent. Any
 * token holder writes through the same handlers, and all of them are logged —
 * so the table is named after the boundary it records, not after one of the
 * clients that crosses it. `user_id` and `token_id` say who it actually was.
 *
 * ## Why the snapshots are JSON and not columns
 *
 * A page has forty fields and a media item a dozen, and the set changes as the
 * CMS grows. The snapshot is the handler's own public projection — exactly the
 * JSON the API answered with — so the log records what the client saw rather
 * than a second, parallel description of a page that would drift from the
 * first. It is written to be read by a person, not queried by the application.
 *
 * ## Why both foreign keys are nullable and `SET NULL`
 *
 * A change outlives the user who made it and the token they used. Deleting a
 * token must not take the record of what it did with it — that is precisely the
 * record somebody deleting a token might want gone. The site cascade is
 * different: a deleted site has no history worth keeping, and a tenant's rows
 * must not survive the tenant.
 */
component {

	function up( schema, qb ){
		queryExecute(
			"
			CREATE TABLE `api_change_log` (
				`id`            BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
				`site_id`       BIGINT UNSIGNED NOT NULL,
				`user_id`       BIGINT UNSIGNED NULL,
				`token_id`      BIGINT UNSIGNED NULL,
				-- `create`, `update`, `publish`, `unpublish`, `delete`, `upload`.
				`action`        VARCHAR(32)     NOT NULL,
				-- `page`, `media`. Text rather than an enum: a module that
				-- gains an API resource must not need a migration here.
				`resource_type` VARCHAR(32)     NOT NULL,
				`resource_id`   BIGINT UNSIGNED NULL,
				-- MEDIUMTEXT, because a page snapshot carries its whole body
				-- and TEXT's 64KB is reachable by a long article.
				`before_json`   MEDIUMTEXT      NULL,
				`after_json`    MEDIUMTEXT      NULL,
				`created_at`    DATETIME        NOT NULL,
				PRIMARY KEY (`id`),
				-- The read the screen makes: this site's changes, newest first.
				KEY `idx_api_change_log_site_created` (`site_id`, `created_at`),
				-- And the one somebody asks about a single page.
				KEY `idx_api_change_log_resource` (`site_id`, `resource_type`, `resource_id`),
				CONSTRAINT `fk_api_change_log_site`
					FOREIGN KEY (`site_id`) REFERENCES `sites` (`id`)
					ON DELETE CASCADE ON UPDATE CASCADE,
				CONSTRAINT `fk_api_change_log_user`
					FOREIGN KEY (`user_id`) REFERENCES `users` (`id`)
					ON DELETE SET NULL,
				CONSTRAINT `fk_api_change_log_token`
					FOREIGN KEY (`token_id`) REFERENCES `api_tokens` (`id`)
					ON DELETE SET NULL
			) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
			",
			{},
			arguments.schema.getDefaultOptions()
		);
	}

	function down( schema, qb ){
		queryExecute( "DROP TABLE IF EXISTS `api_change_log`", {}, arguments.schema.getDefaultOptions() );
	}

}
