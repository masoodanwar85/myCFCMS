/**
 * Uploaded files, per site.
 *
 * The row is the record; the file on disk is just bytes. Everything the CMS
 * needs to render or manage an upload lives here, so a missing file degrades to
 * a broken image rather than an unexplained gap in the library.
 *
 * Files are stored **outside the webroot** and served through a handler that
 * scopes them to the current tenant. Putting them under `public/` would have
 * been faster, but it would also mean one site's uploads are reachable from
 * every other site's domain, and that an upload that slipped past validation
 * sits in a directory the web server will happily execute.
 *
 * `stored_path` is the location relative to the media root; `filename` is what
 * we generated, `original_filename` what the person actually uploaded. Keeping
 * both means the library can show a recognisable name without ever trusting one
 * for a filesystem operation.
 */
component {

	function up( schema, qb ){
		queryExecute(
			"
			CREATE TABLE `media` (
				`id`                BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
				`site_id`           BIGINT UNSIGNED NOT NULL,
				`filename`          VARCHAR(191)    NOT NULL,
				`original_filename` VARCHAR(255)    NOT NULL,
				`stored_path`       VARCHAR(500)    NOT NULL,
				`extension`         VARCHAR(10)     NOT NULL,
				`mime_type`         VARCHAR(100)    NOT NULL,
				`byte_size`         BIGINT UNSIGNED NOT NULL,
				`width`             INT             NULL,
				`height`            INT             NULL,
				`alt_text`          VARCHAR(255)    NULL,
				`title`             VARCHAR(255)    NULL,
				`uploaded_by`       BIGINT UNSIGNED NULL,
				`created_at`        DATETIME        NOT NULL,
				`updated_at`        DATETIME        NOT NULL,
				PRIMARY KEY (`id`),
				-- The lookup behind every /media/... request, and the reason two
				-- uploads cannot claim the same URL on one site.
				UNIQUE KEY `uq_media_site_path` (`site_id`, `stored_path`),
				KEY `idx_media_site_created` (`site_id`, `created_at`),
				KEY `idx_media_uploaded_by` (`uploaded_by`),
				CONSTRAINT `fk_media_site`
					FOREIGN KEY (`site_id`) REFERENCES `sites` (`id`)
					ON DELETE CASCADE ON UPDATE CASCADE,
				-- An upload outlives the person who uploaded it.
				CONSTRAINT `fk_media_uploaded_by`
					FOREIGN KEY (`uploaded_by`) REFERENCES `users` (`id`)
					ON DELETE SET NULL
			) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
			",
			{},
			arguments.schema.getDefaultOptions()
		);
	}

	function down( schema, qb ){
		queryExecute( "DROP TABLE IF EXISTS `media`", {}, arguments.schema.getDefaultOptions() );
	}

}
