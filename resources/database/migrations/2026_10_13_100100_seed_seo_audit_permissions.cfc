/**
 * The permissions the SEO audit module defines.
 *
 * Registered by the module's own migration into Core's global catalogue.
 * Core stores the slugs without knowing what they mean.
 *
 * `view` and `run` are separate because they cost different things. Reading
 * last night's report is free; starting a run fetches every public URL of the
 * site, which is real work on the server. An editor should be able to see what
 * is wrong with their pages without being able to start that.
 */
component {

	variables.PERMISSIONS = [
		{ slug : "seo.view", name : "View SEO audits", description : "See on-page SEO reports for the site." },
		{ slug : "seo.run",  name : "Run SEO audits",  description : "Start an audit, which fetches every public URL of the site." }
	];

	function up( schema, qb ){
		var options = arguments.schema.getDefaultOptions();
		var stamp   = now();

		for ( var permission in variables.PERMISSIONS ) {
			queryExecute(
				"
				INSERT INTO `permissions` ( `slug`, `name`, `description`, `created_at`, `updated_at` )
				VALUES ( :slug, :name, :description, :createdAt, :updatedAt )
				",
				{
					slug        : { value : permission.slug, cfsqltype : "cf_sql_varchar" },
					name        : { value : permission.name, cfsqltype : "cf_sql_varchar" },
					description : { value : permission.description, cfsqltype : "cf_sql_varchar" },
					createdAt   : { value : stamp, cfsqltype : "cf_sql_timestamp" },
					updatedAt   : { value : stamp, cfsqltype : "cf_sql_timestamp" }
				},
				options
			);
		}
	}

	function down( schema, qb ){
		var options = arguments.schema.getDefaultOptions();

		for ( var permission in variables.PERMISSIONS ) {
			queryExecute(
				"DELETE FROM `permissions` WHERE `slug` = :slug",
				{ slug : { value : permission.slug, cfsqltype : "cf_sql_varchar" } },
				options
			);
		}
	}

}
