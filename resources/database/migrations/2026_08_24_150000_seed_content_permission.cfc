/**
 * Group 6 — the permission that lets an author store unsanitised HTML.
 *
 * Content is sanitised by default. Embedding an analytics snippet, a video
 * iframe or a payment widget needs raw markup, so a site can grant this to the
 * few people it trusts with it.
 *
 * Deliberately not added to any seeded role. `owner` picks it up because that
 * role is resolved from the whole catalogue at seed time, which is the intent —
 * a site's owner may embed third-party markup; a run-of-the-mill editor may not.
 */
component {

	variables.PERMISSION = {
		slug        : "content.unfiltered",
		name        : "Publish unfiltered HTML",
		description : "Store content without HTML sanitising. Allows scripts and embeds, so grant it sparingly."
	};

	function up( schema, qb ){
		var stamp = now();

		queryExecute(
			"
			INSERT INTO `permissions` ( `slug`, `name`, `description`, `created_at`, `updated_at` )
			VALUES ( :slug, :name, :description, :createdAt, :updatedAt )
			",
			{
				slug        : { value : variables.PERMISSION.slug, cfsqltype : "cf_sql_varchar" },
				name        : { value : variables.PERMISSION.name, cfsqltype : "cf_sql_varchar" },
				description : { value : variables.PERMISSION.description, cfsqltype : "cf_sql_varchar" },
				createdAt   : { value : stamp, cfsqltype : "cf_sql_timestamp" },
				updatedAt   : { value : stamp, cfsqltype : "cf_sql_timestamp" }
			},
			arguments.schema.getDefaultOptions()
		);
	}

	function down( schema, qb ){
		queryExecute(
			"DELETE FROM `permissions` WHERE `slug` = :slug",
			{ slug : { value : variables.PERMISSION.slug, cfsqltype : "cf_sql_varchar" } },
			arguments.schema.getDefaultOptions()
		);
	}

}
