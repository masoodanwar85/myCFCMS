/**
 * Progress for a run that now happens in the background.
 *
 * A run holds no request open any more, so the only way the report can say what
 * is happening is to read it off the row. `url_count` already records how many
 * URLs have been fetched; `queued_count` is how many are still waiting, which
 * is what turns "47 fetched" into "47 fetched, 12 to go".
 *
 * Neither is a total, because a crawl does not know its total: URLs are
 * discovered from the links on pages already fetched. A progress bar would need
 * a denominator that does not exist, so the report shows two honest counts
 * instead of a dishonest percentage.
 *
 * `heartbeat_at` is what tells a stalled run from a slow one. A thread killed
 * by a restart or an out-of-memory cannot mark its own row failed, so without
 * this the row stays `running` for ever and the report polls for ever. The run
 * touches it as it goes; anything `running` whose heartbeat is old is dead.
 */
component {

	function up( schema, qb ){
		var options = arguments.schema.getDefaultOptions();

		queryExecute(
			"
			ALTER TABLE `seo_audits`
				ADD COLUMN `queued_count` INT      NOT NULL DEFAULT 0 AFTER `url_count`,
				ADD COLUMN `heartbeat_at` DATETIME NULL               AFTER `finished_at`
			",
			{},
			options
		);

		// Existing finished runs get a heartbeat so a later "is this stalled?"
		// query does not have to special-case a null.
		queryExecute(
			"UPDATE `seo_audits` SET `heartbeat_at` = `finished_at` WHERE `finished_at` IS NOT NULL",
			{},
			options
		);
	}

	function down( schema, qb ){
		var options = arguments.schema.getDefaultOptions();

		queryExecute(
			"
			ALTER TABLE `seo_audits`
				DROP COLUMN `queued_count`,
				DROP COLUMN `heartbeat_at`
			",
			{},
			options
		);
	}

}
