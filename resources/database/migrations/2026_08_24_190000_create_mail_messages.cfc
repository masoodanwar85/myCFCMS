/**
 * A record of every email the CMS tried to send.
 *
 * There is no mail server configured in development, and there may not be one
 * in production for a while. Without a record, "did the contact form notify
 * anyone?" is unanswerable — and a notification that silently failed looks
 * exactly like one that was never triggered.
 *
 * So every attempt is written down: what was sent, to whom, and whether it
 * left. That makes the mail layer observable before it is even connected, and
 * gives the admin somewhere to look when a client says they never got an email.
 *
 * `site_id` is nullable because platform mail — a password reset for a super
 * admin — belongs to no tenant.
 */
component {

	function up( schema, qb ){
		queryExecute(
			"
			CREATE TABLE `mail_messages` (
				`id`           BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
				`site_id`      BIGINT UNSIGNED NULL,
				`to_address`   VARCHAR(191)    NOT NULL,
				`from_address` VARCHAR(191)    NOT NULL,
				`reply_to`     VARCHAR(191)    NULL,
				`subject`      VARCHAR(255)    NOT NULL,
				`body`         MEDIUMTEXT      NULL,
				`content_type` VARCHAR(20)     NOT NULL DEFAULT 'html',
				`status`       VARCHAR(20)     NOT NULL DEFAULT 'queued',
				`error`        VARCHAR(500)    NULL,
				`sent_at`      DATETIME        NULL,
				`created_at`   DATETIME        NOT NULL,
				PRIMARY KEY (`id`),
				KEY `idx_mail_messages_site_status` (`site_id`, `status`, `created_at`),
				KEY `idx_mail_messages_created` (`created_at`),
				CONSTRAINT `ck_mail_messages_status`
					CHECK (`status` IN ('queued','sent','failed','suppressed')),
				CONSTRAINT `ck_mail_messages_type`
					CHECK (`content_type` IN ('html','text')),
				CONSTRAINT `fk_mail_messages_site`
					FOREIGN KEY (`site_id`) REFERENCES `sites` (`id`)
					ON DELETE CASCADE ON UPDATE CASCADE
			) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
			",
			{},
			arguments.schema.getDefaultOptions()
		);
	}

	function down( schema, qb ){
		queryExecute( "DROP TABLE IF EXISTS `mail_messages`", {}, arguments.schema.getDefaultOptions() );
	}

}
