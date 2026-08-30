/**
 * Will module tables.
 *
 * Domain columns (`wm_fullname`, `poa_name`, `gift_item`, …) are the questionnaire
 * fields as specified. Structural columns follow the rest of the CMS:
 *
 *   - `id` as the primary key (not `submissionID` / `giftID`)
 *   - `site_id` on every row, FK → `sites.id` CASCADE
 *   - `user_id` SET NULL, so removing an account does not remove a will
 *   - `created_at` / `updated_at` (not `dateCreated` / `dateLastUpdate`)
 *   - `sort_order` (not `sortOrder`)
 *   - children carry `site_id` and a composite FK `(submission_id, site_id)`
 *     so a gift or executor cannot be attached to another site's submission
 */
component {

	function up( schema, qb ){
		var options = arguments.schema.getDefaultOptions();

		queryExecute(
			"
			CREATE TABLE `will_submission` (
				`id`                   BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
				`site_id`              BIGINT UNSIGNED NOT NULL,
				`user_id`              BIGINT UNSIGNED NULL,
				`status`               VARCHAR(50)     NOT NULL DEFAULT 'submitted',
				`current_step`         TINYINT         NULL,
				`wm_fullname`          VARCHAR(255)    NOT NULL,
				`wm_dob`               DATE            NOT NULL,
				`wm_marital`           VARCHAR(50)     NOT NULL,
				`wm_address`           VARCHAR(500)    NOT NULL,
				`wm_email`             VARCHAR(255)    NOT NULL,
				`wm_phone`             VARCHAR(50)     NULL,
				`ex_name`              VARCHAR(255)    NOT NULL,
				`ex_address`           VARCHAR(500)    NOT NULL,
				`ex_relationship`      VARCHAR(255)    NULL,
				`ex_email`             VARCHAR(255)    NULL,
				`ex_phone`             VARCHAR(50)     NULL,
				`ex_can_charge_fees`   TINYINT(1)      NOT NULL DEFAULT 0,
				`ex_act_mode`          VARCHAR(50)     NULL,
				`guard_name`           VARCHAR(255)    NULL,
				`guard_address`        VARCHAR(500)    NULL,
				`guard_children`       LONGTEXT        NULL,
				`estate_residue`       LONGTEXT        NOT NULL,
				`poa_name`             VARCHAR(255)    NULL,
				`poa_address`          VARCHAR(500)    NULL,
				`poa_email`            VARCHAR(255)    NULL,
				`poa_phone`            VARCHAR(50)     NULL,
				`poa_commence`         VARCHAR(255)    NULL,
				`poa_act_mode`         VARCHAR(50)     NULL,
				`eg_name`              VARCHAR(255)    NULL,
				`eg_address`           VARCHAR(500)    NULL,
				`eg_email`             VARCHAR(255)    NULL,
				`eg_phone`             VARCHAR(50)     NULL,
				`eg_directions`        LONGTEXT        NULL,
				`eg_act_mode`          VARCHAR(50)     NULL,
				`body_disposal`        VARCHAR(50)     NULL,
				`body_instructions`    LONGTEXT        NULL,
				`da_include_clauses`   VARCHAR(10)     NULL,
				`da_instructions`      LONGTEXT        NULL,
				`da_notes`             LONGTEXT        NULL,
				`consent_accepted`     TINYINT(1)      NOT NULL DEFAULT 0,
				`consent_accepted_at`  DATETIME        NULL,
				`ip_address`           VARCHAR(45)     NULL,
				`user_agent`           VARCHAR(500)    NULL,
				`notes`                LONGTEXT        NULL,
				`created_at`           DATETIME        NOT NULL,
				`updated_at`           DATETIME        NOT NULL,
				PRIMARY KEY (`id`),
				UNIQUE KEY `uq_will_submission_id_site` (`id`, `site_id`),
				KEY `idx_will_submission_site_status` (`site_id`, `status`, `created_at`),
				KEY `idx_will_submission_email` (`wm_email`),
				KEY `idx_will_submission_user` (`user_id`),
				CONSTRAINT `fk_will_submission_site`
					FOREIGN KEY (`site_id`) REFERENCES `sites` (`id`)
					ON DELETE CASCADE ON UPDATE CASCADE,
				CONSTRAINT `fk_will_submission_user`
					FOREIGN KEY (`user_id`) REFERENCES `users` (`id`)
					ON DELETE SET NULL
			) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
			",
			{},
			options
		);

		queryExecute(
			"
			CREATE TABLE `will_gift` (
				`id`            BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
				`site_id`       BIGINT UNSIGNED NOT NULL,
				`submission_id` BIGINT UNSIGNED NOT NULL,
				`sort_order`    INT             NOT NULL DEFAULT 1,
				`gift_item`     VARCHAR(500)    NOT NULL,
				`gift_beneficiary` VARCHAR(500) NOT NULL,
				`created_at`    DATETIME        NOT NULL,
				PRIMARY KEY (`id`),
				KEY `idx_will_gift_submission` (`site_id`, `submission_id`, `sort_order`),
				CONSTRAINT `fk_will_gift_site`
					FOREIGN KEY (`site_id`) REFERENCES `sites` (`id`)
					ON DELETE CASCADE ON UPDATE CASCADE,
				CONSTRAINT `fk_will_gift_submission`
					FOREIGN KEY (`submission_id`, `site_id`)
					REFERENCES `will_submission` (`id`, `site_id`)
					ON DELETE CASCADE ON UPDATE CASCADE
			) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
			",
			{},
			options
		);

		queryExecute(
			"
			CREATE TABLE `will_substitute_executor` (
				`id`                 BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
				`site_id`            BIGINT UNSIGNED NOT NULL,
				`submission_id`      BIGINT UNSIGNED NOT NULL,
				`sort_order`         INT             NOT NULL DEFAULT 1,
				`ex_name`            VARCHAR(255)    NOT NULL,
				`ex_address`         VARCHAR(500)    NULL,
				`ex_relationship`    VARCHAR(255)    NULL,
				`ex_email`           VARCHAR(255)    NULL,
				`ex_phone`           VARCHAR(50)     NULL,
				`ex_can_charge_fees` TINYINT(1)      NOT NULL DEFAULT 0,
				`created_at`         DATETIME        NOT NULL,
				PRIMARY KEY (`id`),
				KEY `idx_will_sub_ex_submission` (`site_id`, `submission_id`, `sort_order`),
				CONSTRAINT `fk_will_sub_ex_site`
					FOREIGN KEY (`site_id`) REFERENCES `sites` (`id`)
					ON DELETE CASCADE ON UPDATE CASCADE,
				CONSTRAINT `fk_will_sub_ex_submission`
					FOREIGN KEY (`submission_id`, `site_id`)
					REFERENCES `will_submission` (`id`, `site_id`)
					ON DELETE CASCADE ON UPDATE CASCADE
			) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
			",
			{},
			options
		);

		queryExecute(
			"
			CREATE TABLE `will_backup_guardian` (
				`id`              BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
				`site_id`         BIGINT UNSIGNED NOT NULL,
				`submission_id`   BIGINT UNSIGNED NOT NULL,
				`sort_order`      INT             NOT NULL DEFAULT 1,
				`guard_name`      VARCHAR(255)    NOT NULL,
				`guard_address`   VARCHAR(500)    NULL,
				`guard_children`  LONGTEXT        NULL,
				`created_at`      DATETIME        NOT NULL,
				PRIMARY KEY (`id`),
				KEY `idx_will_bak_guard_submission` (`site_id`, `submission_id`, `sort_order`),
				CONSTRAINT `fk_will_bak_guard_site`
					FOREIGN KEY (`site_id`) REFERENCES `sites` (`id`)
					ON DELETE CASCADE ON UPDATE CASCADE,
				CONSTRAINT `fk_will_bak_guard_submission`
					FOREIGN KEY (`submission_id`, `site_id`)
					REFERENCES `will_submission` (`id`, `site_id`)
					ON DELETE CASCADE ON UPDATE CASCADE
			) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
			",
			{},
			options
		);

		queryExecute(
			"
			CREATE TABLE `will_additional_attorney` (
				`id`             BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
				`site_id`        BIGINT UNSIGNED NOT NULL,
				`submission_id`  BIGINT UNSIGNED NOT NULL,
				`sort_order`     INT             NOT NULL DEFAULT 1,
				`poa_name`       VARCHAR(255)    NOT NULL,
				`poa_address`    VARCHAR(500)    NULL,
				`poa_email`      VARCHAR(255)    NULL,
				`poa_phone`      VARCHAR(50)     NULL,
				`poa_commence`   VARCHAR(255)    NULL,
				`created_at`     DATETIME        NOT NULL,
				PRIMARY KEY (`id`),
				KEY `idx_will_add_poa_submission` (`site_id`, `submission_id`, `sort_order`),
				CONSTRAINT `fk_will_add_poa_site`
					FOREIGN KEY (`site_id`) REFERENCES `sites` (`id`)
					ON DELETE CASCADE ON UPDATE CASCADE,
				CONSTRAINT `fk_will_add_poa_submission`
					FOREIGN KEY (`submission_id`, `site_id`)
					REFERENCES `will_submission` (`id`, `site_id`)
					ON DELETE CASCADE ON UPDATE CASCADE
			) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
			",
			{},
			options
		);

		queryExecute(
			"
			CREATE TABLE `will_backup_enduring_guardian` (
				`id`             BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
				`site_id`        BIGINT UNSIGNED NOT NULL,
				`submission_id`  BIGINT UNSIGNED NOT NULL,
				`sort_order`     INT             NOT NULL DEFAULT 1,
				`eg_name`        VARCHAR(255)    NOT NULL,
				`eg_address`     VARCHAR(500)    NULL,
				`eg_email`       VARCHAR(255)    NULL,
				`eg_phone`       VARCHAR(50)     NULL,
				`eg_directions`  LONGTEXT        NULL,
				`created_at`     DATETIME        NOT NULL,
				PRIMARY KEY (`id`),
				KEY `idx_will_bak_eg_submission` (`site_id`, `submission_id`, `sort_order`),
				CONSTRAINT `fk_will_bak_eg_site`
					FOREIGN KEY (`site_id`) REFERENCES `sites` (`id`)
					ON DELETE CASCADE ON UPDATE CASCADE,
				CONSTRAINT `fk_will_bak_eg_submission`
					FOREIGN KEY (`submission_id`, `site_id`)
					REFERENCES `will_submission` (`id`, `site_id`)
					ON DELETE CASCADE ON UPDATE CASCADE
			) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
			",
			{},
			options
		);
	}

	function down( schema, qb ){
		var options = arguments.schema.getDefaultOptions();

		queryExecute( "DROP TABLE IF EXISTS `will_backup_enduring_guardian`", {}, options );
		queryExecute( "DROP TABLE IF EXISTS `will_additional_attorney`", {}, options );
		queryExecute( "DROP TABLE IF EXISTS `will_backup_guardian`", {}, options );
		queryExecute( "DROP TABLE IF EXISTS `will_substitute_executor`", {}, options );
		queryExecute( "DROP TABLE IF EXISTS `will_gift`", {}, options );
		queryExecute( "DROP TABLE IF EXISTS `will_submission`", {}, options );
	}

}
