/**
 * FAQs — questions and answers, ordered per site.
 *
 * A published FAQ is shown in the public accordion at /faq. Drafts stay
 * in the admin list until they are published.
 */
component {

	function up( schema, qb ){
		var options = arguments.schema.getDefaultOptions();

		queryExecute(
			"
			CREATE TABLE `faqs` (
				`id`            BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
				`site_id`       BIGINT UNSIGNED NOT NULL,
				`question`      VARCHAR(500)    NOT NULL,
				`answer`        MEDIUMTEXT      NULL,
				`sort_order`    INT             NOT NULL DEFAULT 0,
				`is_published`  TINYINT(1)      NOT NULL DEFAULT 0,
				`created_at`    DATETIME        NOT NULL,
				`updated_at`    DATETIME        NOT NULL,
				PRIMARY KEY (`id`),
				KEY `idx_faqs_site_published_order` (`site_id`, `is_published`, `sort_order`),
				CONSTRAINT `fk_faqs_site`
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

		queryExecute( "DROP TABLE IF EXISTS `faqs`", {}, options );
	}

}
