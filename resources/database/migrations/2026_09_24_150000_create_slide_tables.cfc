/**
 * Hero slides: a background image, overlay HTML, and where that HTML sits.
 */
component {

	function up( schema, qb ){
		var options = arguments.schema.getDefaultOptions();

		queryExecute(
			"
			CREATE TABLE `slides` (
				`id`            BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
				`site_id`       BIGINT UNSIGNED NOT NULL,
				`image_url`     VARCHAR(500)    NULL,
				`image_alt`     VARCHAR(255)    NULL,
				`overlay_html`  MEDIUMTEXT      NULL,
				`h_align`       VARCHAR(10)     NOT NULL DEFAULT 'left',
				`v_align`       VARCHAR(10)     NOT NULL DEFAULT 'middle',
				`sort_order`    INT             NOT NULL DEFAULT 0,
				`is_published`  TINYINT(1)      NOT NULL DEFAULT 0,
				`created_at`    DATETIME        NOT NULL,
				`updated_at`    DATETIME        NOT NULL,
				PRIMARY KEY (`id`),
				KEY `idx_slides_site_published_order` (`site_id`, `is_published`, `sort_order`),
				CONSTRAINT `ck_slides_h_align`
					CHECK (`h_align` IN ('left','center','right')),
				CONSTRAINT `ck_slides_v_align`
					CHECK (`v_align` IN ('top','middle','bottom')),
				CONSTRAINT `fk_slides_site`
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

		queryExecute( "DROP TABLE IF EXISTS `slides`", {}, options );
	}

}
