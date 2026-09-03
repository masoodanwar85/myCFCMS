/**
 * The Forms module — author-defined forms with their own fields.
 *
 * Contact owns one thing well: a site's enquiry form, with fixed fields and a
 * recipient. When it also tried to be plural it produced forms nobody could
 * reach. This module is the other half of that split: a form whose *fields* an
 * author defines, with its own submissions and its own inbox.
 *
 * ## Three tables, not two
 *
 * `form_fields` is a real table rather than JSON on the form, because fields are
 * ordered, typed, individually edited and validated against on every
 * submission. A JSON blob would have to be parsed and re-serialised for every
 * one of those.
 *
 * `form_submissions.answers` is the opposite choice: a JSON document, not an
 * EAV table keyed by `field_id`. That is deliberate and it is the more
 * important decision of the two.
 *
 * A submission is a **record of what was actually asked**. With rows keyed by
 * `field_id`, renaming a field rewrites history — an answer given under "Your
 * budget" starts displaying under "Project value" — and deleting a field either
 * orphans answers or cascades them away. Storing the label alongside the value
 * at submission time makes an old submission still readable years after the
 * form changed, which is the whole point of keeping it.
 *
 * It also keeps reading one submission to a single row, which is how the admin
 * reads them: one at a time, in full.
 *
 * The cost is that answers cannot be filtered in SQL. Nothing asks to, and the
 * day something does, `answers` is JSON in MySQL 8 and can be indexed with a
 * generated column without moving the data.
 *
 * ## `TEXT`, not the `JSON` type
 *
 * Stored as `MEDIUMTEXT` holding JSON rather than as MySQL's `JSON` column.
 * This project is developed on ColdFusion 2025 and deployed on 2023, and the
 * JDBC binding of a string into a `JSON` column is exactly the kind of
 * engine-specific behaviour that has already cost this codebase a production
 * outage. The application serialises and validates the document; the database
 * stores it.
 */
component {

	function up( schema, qb ){
		var options = arguments.schema.getDefaultOptions();

		/**
		 * A form. Tenant-scoped, and unique by slug within a site so
		 * `[form slug="..."]` names exactly one thing.
		 *
		 * `uq_forms_id_site` exists to be the target of the composite foreign
		 * keys below — the same trick `users`/`roles` use, so a field or a
		 * submission cannot be attached to another site's form even if an id
		 * were guessed.
		 */
		queryExecute(
			"
			CREATE TABLE `forms` (
				`id`              BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
				`site_id`         BIGINT UNSIGNED NOT NULL,
				`name`            VARCHAR(150)    NOT NULL,
				`slug`            VARCHAR(150)    NOT NULL,
				`intro`           TEXT            NULL,
				`submit_label`    VARCHAR(100)    NOT NULL DEFAULT 'Send',
				`success_message` VARCHAR(500)    NOT NULL DEFAULT 'Thank you. We have received your response.',
				`thank_you_path`  VARCHAR(500)    NULL,
				`recipient_email` VARCHAR(191)    NULL,
				`store_submissions` TINYINT(1)    NOT NULL DEFAULT 1,
				`is_active`       TINYINT(1)      NOT NULL DEFAULT 1,
				`created_at`      DATETIME        NOT NULL,
				`updated_at`      DATETIME        NOT NULL,
				PRIMARY KEY (`id`),
				UNIQUE KEY `uq_forms_site_slug` (`site_id`, `slug`),
				UNIQUE KEY `uq_forms_id_site` (`id`, `site_id`),
				KEY `idx_forms_site_active` (`site_id`, `is_active`),
				CONSTRAINT `fk_forms_site`
					FOREIGN KEY (`site_id`) REFERENCES `sites` (`id`)
					ON DELETE CASCADE ON UPDATE CASCADE
			) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
			",
			{},
			options
		);

		/**
		 * One field on a form.
		 *
		 * `field_key` is what appears in the posted data and in the answers
		 * document. Unique per form, and stable: renaming a field's *label* is
		 * a display change, while changing its key would orphan every answer
		 * already stored under the old one.
		 *
		 * `options_text` is newline-separated rather than JSON. An author edits
		 * it in a textarea, one option per line, and a format they can read and
		 * fix by hand beats one that needs a parser to explain a syntax error.
		 */
		queryExecute(
			"
			CREATE TABLE `form_fields` (
				`id`          BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
				`site_id`     BIGINT UNSIGNED NOT NULL,
				`form_id`     BIGINT UNSIGNED NOT NULL,
				`field_type`  VARCHAR(20)     NOT NULL,
				`field_key`   VARCHAR(64)     NOT NULL,
				`label`       VARCHAR(200)    NOT NULL,
				`placeholder` VARCHAR(200)    NULL,
				`help_text`   VARCHAR(500)    NULL,
				`options_text` TEXT           NULL,
				`is_required` TINYINT(1)      NOT NULL DEFAULT 0,
				`max_length`  SMALLINT UNSIGNED NULL,
				`sort_order`  INT             NOT NULL DEFAULT 0,
				`created_at`  DATETIME        NOT NULL,
				`updated_at`  DATETIME        NOT NULL,
				PRIMARY KEY (`id`),
				UNIQUE KEY `uq_form_fields_form_key` (`form_id`, `field_key`),
				KEY `idx_form_fields_form_order` (`form_id`, `sort_order`),
				CONSTRAINT `ck_form_fields_type` CHECK (
					`field_type` IN ('text','textarea','email','tel','number','select','radio','checkbox','date')
				),
				CONSTRAINT `fk_form_fields_form`
					FOREIGN KEY (`form_id`, `site_id`) REFERENCES `forms` (`id`, `site_id`)
					ON DELETE CASCADE ON UPDATE CASCADE
			) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
			",
			{},
			options
		);

		/**
		 * What somebody sent.
		 *
		 * `answers` is a JSON array of `{ key, label, type, value }` — the
		 * question as it was asked, next to the answer. See the note at the top
		 * of this file for why that beats rows keyed by `field_id`.
		 *
		 * `sender_email` is denormalised out of the answers so the inbox can
		 * show a sender and the notification can set a reply-to without parsing
		 * the document. Null when the form asks for no email address, which is
		 * allowed — not every form is a way of being contacted back.
		 */
		queryExecute(
			"
			CREATE TABLE `form_submissions` (
				`id`           BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
				`site_id`      BIGINT UNSIGNED NOT NULL,
				`form_id`      BIGINT UNSIGNED NOT NULL,
				`answers`      MEDIUMTEXT      NOT NULL,
				`sender_email` VARCHAR(191)    NULL,
				`summary`      VARCHAR(255)    NULL,
				`status`       VARCHAR(20)     NOT NULL DEFAULT 'new',
				`ip_address`   VARCHAR(45)     NULL,
				`user_agent`   VARCHAR(255)    NULL,
				`created_at`   DATETIME        NOT NULL,
				`updated_at`   DATETIME        NOT NULL,
				PRIMARY KEY (`id`),
				KEY `idx_form_submissions_site_status` (`site_id`, `status`, `created_at`),
				KEY `idx_form_submissions_form` (`form_id`),
				CONSTRAINT `ck_form_submissions_status` CHECK (`status` IN ('new','read','spam')),
				CONSTRAINT `fk_form_submissions_form`
					FOREIGN KEY (`form_id`, `site_id`) REFERENCES `forms` (`id`, `site_id`)
					ON DELETE CASCADE ON UPDATE CASCADE
			) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
			",
			{},
			options
		);
	}

	function down( schema, qb ){
		var options = arguments.schema.getDefaultOptions();

		// Children first: both carry composite foreign keys onto `forms`.
		queryExecute( "DROP TABLE IF EXISTS `form_submissions`", {}, options );
		queryExecute( "DROP TABLE IF EXISTS `form_fields`", {}, options );
		queryExecute( "DROP TABLE IF EXISTS `forms`", {}, options );
	}

}
