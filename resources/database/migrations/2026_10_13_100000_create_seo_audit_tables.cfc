/**
 * On-page SEO audits: one row per run, one row per finding.
 *
 * ## Why findings are stored and not computed on demand
 *
 * A run fetches and parses every public URL of a site. That is seconds of work
 * and a request per page, so it cannot happen every time somebody opens the
 * report. Storing it also makes the obvious question answerable — "is this
 * better than last week?" — which a recomputed-every-time report never is.
 *
 * ## Why the URL is denormalised onto the finding
 *
 * A finding records the URL it was found at as text, not a foreign key to
 * `pages`. Two reasons, and the second is the one that decides it:
 *
 *   - Not every audited URL is a page. `/faq` and `/contact` are served by
 *     their modules' content resolvers and have no row in `pages`.
 *   - A finding is a statement about the past. If a page is renamed or deleted
 *     after a run, the finding should still read as what was true when the run
 *     happened, rather than following the page to its new URL or vanishing.
 *
 * `page_id` is kept alongside, nullable, purely so the report can offer an
 * "edit this page" link when the URL does happen to be a page.
 */
component {

	function up( schema, qb ){
		var options = arguments.schema.getDefaultOptions();

		queryExecute(
			"
			CREATE TABLE `seo_audits` (
				`id`           BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
				`site_id`      BIGINT UNSIGNED NOT NULL,
				`status`       VARCHAR(16)     NOT NULL DEFAULT 'running',
				`started_at`   DATETIME        NOT NULL,
				`finished_at`  DATETIME        NULL,
				`url_count`    INT             NOT NULL DEFAULT 0,
				`error_count`  INT             NOT NULL DEFAULT 0,
				`warning_count` INT            NOT NULL DEFAULT 0,
				`notice_count` INT             NOT NULL DEFAULT 0,
				-- Why a run stopped short, when it did: an unreachable site, or
				-- the URL cap. Empty on a clean run.
				`note`         VARCHAR(500)    NULL,
				`run_by`       BIGINT UNSIGNED NULL,
				`created_at`   DATETIME        NOT NULL,
				`updated_at`   DATETIME        NOT NULL,
				PRIMARY KEY (`id`),
				KEY `idx_seo_audits_site_started` (`site_id`, `started_at`),
				CONSTRAINT `fk_seo_audits_site`
					FOREIGN KEY (`site_id`) REFERENCES `sites` (`id`)
					ON DELETE CASCADE ON UPDATE CASCADE,
				-- A run outlives the person who started it.
				CONSTRAINT `fk_seo_audits_run_by`
					FOREIGN KEY (`run_by`) REFERENCES `users` (`id`)
					ON DELETE SET NULL
			) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
			",
			{},
			options
		);

		queryExecute(
			"
			CREATE TABLE `seo_audit_issues` (
				`id`        BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
				`audit_id`  BIGINT UNSIGNED NOT NULL,
				`site_id`   BIGINT UNSIGNED NOT NULL,
				`path`      VARCHAR(500)    NOT NULL,
				`page_id`   BIGINT UNSIGNED NULL,
				-- The check that produced this, e.g. `title.tooLong`. Stored as
				-- a slug so the report can group by it without matching on
				-- human-readable text that a wording change would break.
				`check_id`  VARCHAR(64)     NOT NULL,
				`severity`  VARCHAR(16)     NOT NULL,
				`message`   VARCHAR(500)    NOT NULL,
				-- The offending value, truncated: the title that was too long,
				-- the image that had no alt. What makes a finding actionable
				-- without opening the page.
				`detail`    VARCHAR(1000)   NULL,
				`created_at` DATETIME       NOT NULL,
				PRIMARY KEY (`id`),
				KEY `idx_seo_issues_audit` (`audit_id`, `severity`),
				KEY `idx_seo_issues_audit_check` (`audit_id`, `check_id`),
				KEY `idx_seo_issues_page` (`page_id`),
				CONSTRAINT `fk_seo_issues_audit`
					FOREIGN KEY (`audit_id`) REFERENCES `seo_audits` (`id`)
					ON DELETE CASCADE ON UPDATE CASCADE,
				CONSTRAINT `fk_seo_issues_site`
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

		// Issues first: the foreign key would refuse the other order.
		queryExecute( "DROP TABLE IF EXISTS `seo_audit_issues`", {}, options );
		queryExecute( "DROP TABLE IF EXISTS `seo_audits`", {}, options );
	}

}
