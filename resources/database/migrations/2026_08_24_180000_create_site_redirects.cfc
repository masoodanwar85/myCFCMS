/**
 * Remembers where content used to live.
 *
 * Renaming a page moved its URL and every URL beneath it, and nothing recorded
 * the old one. Links a client had already published, and everything a search
 * engine had indexed, started returning 404 the moment an editor tidied a
 * title. That is silent damage to work that was already correct.
 *
 * A redirect belongs to Core rather than to Pages: any module's content can
 * move, and a visitor arriving on an old URL has no idea which module used to
 * answer it.
 */
component {

	function up( schema, qb ){
		queryExecute(
			"
			CREATE TABLE `site_redirects` (
				`id`          BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
				`site_id`     BIGINT UNSIGNED NOT NULL,
				`from_path`   VARCHAR(500)    NOT NULL,
				`to_path`     VARCHAR(500)    NOT NULL,
				`status_code` SMALLINT        NOT NULL DEFAULT 301,
				`created_at`  DATETIME        NOT NULL,
				`updated_at`  DATETIME        NOT NULL,
				PRIMARY KEY (`id`),
				-- One answer per old URL, and the lookup behind every 404.
				UNIQUE KEY `uq_site_redirects_site_from` (`site_id`, `from_path`),
				CONSTRAINT `ck_site_redirects_status`
					CHECK (`status_code` IN (301, 302)),
				-- A redirect to itself is a loop, and the database should not
				-- hold one even if something upstream is confused.
				CONSTRAINT `ck_site_redirects_not_self`
					CHECK (`from_path` <> `to_path`),
				CONSTRAINT `fk_site_redirects_site`
					FOREIGN KEY (`site_id`) REFERENCES `sites` (`id`)
					ON DELETE CASCADE ON UPDATE CASCADE
			) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
			",
			{},
			arguments.schema.getDefaultOptions()
		);
	}

	function down( schema, qb ){
		queryExecute( "DROP TABLE IF EXISTS `site_redirects`", {}, arguments.schema.getDefaultOptions() );
	}

}
