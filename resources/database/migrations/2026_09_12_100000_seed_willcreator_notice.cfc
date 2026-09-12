/**
 * First-visit notice for the Will Creator site.
 *
 * Campaign copy belongs in `site_settings`, not in a theme. This turns the
 * October 2026 will-discount dialog on for the existing `willcreator` tenant
 * so it appears without a manual Settings save. Other tenants are untouched.
 *
 * Skips the site if the keys are already there, so an operator who has since
 * turned the notice off is not overwritten on a later migrate.
 */
component {

	variables.KEYS = [
		{ key : "notice.enabled",    value : "true" },
		// Concatenated: a CFML struct value of `"Special:"` is parsed as `"Special"`.
		{ key : "notice.heading",    value : "Special" & ":" },
		{
			key   : "notice.body",
			value : "Use our Will Creation Tool and create a Will at a reduced rate (a 50% discount) from now through till 31 October 2026."
		},
		{ key : "notice.ctaUrl",     value : "/will" },
		{ key : "notice.ctaLabel",   value : "Create your Will" },
		{ key : "notice.expiresAt",  value : "2026-10-31" }
	];

	function up( schema, qb ){
		var options = arguments.schema.getDefaultOptions();
		var stamp   = now();
		var site    = queryExecute(
			"SELECT `id` FROM `sites` WHERE `slug` = :slug",
			{ slug : { value : "willcreator", cfsqltype : "cf_sql_varchar" } },
			options
		);

		if ( !site.recordCount ) {
			return;
		}

		var siteId = site.id[ 1 ];

		for ( var setting in variables.KEYS ) {
			queryExecute(
				"
				INSERT INTO `site_settings` ( `site_id`, `setting_key`, `setting_value`, `created_at`, `updated_at` )
				SELECT :siteId, :settingKey, :settingValue, :createdAt, :updatedAt
				WHERE NOT EXISTS (
					SELECT 1 FROM `site_settings`
					WHERE `site_id` = :siteId
					  AND `setting_key` = :settingKey
				)
				",
				{
					siteId       : { value : siteId, cfsqltype : "cf_sql_integer" },
					settingKey   : { value : setting.key, cfsqltype : "cf_sql_varchar" },
					settingValue : { value : setting.value, cfsqltype : "cf_sql_longvarchar" },
					createdAt    : { value : stamp, cfsqltype : "cf_sql_timestamp" },
					updatedAt    : { value : stamp, cfsqltype : "cf_sql_timestamp" }
				},
				options
			);
		}
	}

	function down( schema, qb ){
		var options = arguments.schema.getDefaultOptions();

		queryExecute(
			"
			DELETE ss FROM `site_settings` ss
			INNER JOIN `sites` s ON s.`id` = ss.`site_id`
			WHERE s.`slug` = :slug
			  AND ss.`setting_key` IN (
			      'notice.enabled', 'notice.heading', 'notice.body',
			      'notice.ctaUrl', 'notice.ctaLabel', 'notice.expiresAt'
			  )
			",
			{ slug : { value : "willcreator", cfsqltype : "cf_sql_varchar" } },
			options
		);
	}

}
