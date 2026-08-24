/**
 * Group 7 — the Contact module's tables.
 *
 * Contact is the first module that accepts input from people who are not
 * signed in, which is a different problem from anything built so far. Every
 * other write path in the CMS is behind authentication and a permission; this
 * one is open to the internet.
 *
 * That shapes the schema: a submission records where it came from, so abuse can
 * be traced and rate limiting has something to work with later, and it carries
 * a status so a human can triage rather than delete.
 *
 * Requires MySQL 8.0.16+ for the enforced CHECK.
 */
component {

	function up( schema, qb ){
		var options = arguments.schema.getDefaultOptions();

		/**
		 * A form a site publishes. Most sites will have exactly one, but a site
		 * with separate sales and support addresses needs two, and that is
		 * cheaper to allow now than to retrofit.
		 */
		queryExecute(
			"
			CREATE TABLE `contact_forms` (
				`id`               BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
				`site_id`          BIGINT UNSIGNED NOT NULL,
				`name`             VARCHAR(150)    NOT NULL,
				`slug`             VARCHAR(191)    NOT NULL,
				`intro`            TEXT            NULL,
				`recipient_email`  VARCHAR(191)    NULL,
				`success_message`  VARCHAR(500)    NOT NULL DEFAULT 'Thank you. We will be in touch.',
				`is_active`        TINYINT(1)      NOT NULL DEFAULT 1,
				`created_at`       DATETIME        NOT NULL,
				`updated_at`       DATETIME        NOT NULL,
				PRIMARY KEY (`id`),
				UNIQUE KEY `uq_contact_forms_site_slug` (`site_id`, `slug`),
				-- Composite foreign key target, as elsewhere in the project.
				UNIQUE KEY `uq_contact_forms_id_site` (`id`, `site_id`),
				CONSTRAINT `fk_contact_forms_site`
					FOREIGN KEY (`site_id`) REFERENCES `sites` (`id`)
					ON DELETE CASCADE ON UPDATE CASCADE
			) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
			",
			{},
			options
		);

		/**
		 * What a visitor sent.
		 *
		 * `message` is TEXT and stored as submitted — it is displayed to an
		 * admin as escaped text, never as markup, so there is nothing to
		 * sanitise away and nothing gained by mangling what someone wrote.
		 *
		 * `ip_address` is sized for IPv6. It is the only personal data here
		 * beyond what the sender chose to type, and it exists so abuse can be
		 * traced; see the retention note in the docs.
		 */
		queryExecute(
			"
			CREATE TABLE `contact_submissions` (
				`id`           BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
				`site_id`      BIGINT UNSIGNED NOT NULL,
				`form_id`      BIGINT UNSIGNED NOT NULL,
				`name`         VARCHAR(150)    NOT NULL,
				`email`        VARCHAR(191)    NOT NULL,
				`subject`      VARCHAR(255)    NULL,
				`message`      TEXT            NOT NULL,
				`status`       VARCHAR(20)     NOT NULL DEFAULT 'new',
				`ip_address`   VARCHAR(45)     NULL,
				`user_agent`   VARCHAR(255)    NULL,
				`created_at`   DATETIME        NOT NULL,
				`updated_at`   DATETIME        NOT NULL,
				PRIMARY KEY (`id`),
				-- The admin list: this site's submissions, newest first,
				-- optionally filtered by status.
				KEY `idx_contact_submissions_site_status` (`site_id`, `status`, `created_at`),
				KEY `idx_contact_submissions_form` (`form_id`),
				CONSTRAINT `ck_contact_submissions_status`
					CHECK (`status` IN ('new','read','spam')),
				CONSTRAINT `fk_contact_submissions_site`
					FOREIGN KEY (`site_id`) REFERENCES `sites` (`id`)
					ON DELETE CASCADE ON UPDATE CASCADE,
				-- Composite, so a submission cannot be attached to another
				-- site's form.
				CONSTRAINT `fk_contact_submissions_form`
					FOREIGN KEY (`form_id`, `site_id`) REFERENCES `contact_forms` (`id`, `site_id`)
					ON DELETE CASCADE ON UPDATE CASCADE
			) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
			",
			{},
			options
		);
	}

	function down( schema, qb ){
		var options = arguments.schema.getDefaultOptions();

		queryExecute( "DROP TABLE IF EXISTS `contact_submissions`", {}, options );
		queryExecute( "DROP TABLE IF EXISTS `contact_forms`", {}, options );
	}

}
