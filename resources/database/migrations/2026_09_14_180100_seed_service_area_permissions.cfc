/**
 * Permissions for the Service Areas admin screens.
 *
 * Inserts slugs only. Existing owner roles are granted them in the next
 * migration, the same way Forms and Will do.
 */
component {

	variables.PERMISSIONS = [
		{
			slug        : "serviceareas.view",
			name        : "View service areas",
			description : "See the services and locations used on the Service Locations page."
		},
		{
			slug        : "serviceareas.manage",
			name        : "Manage service areas",
			description : "Create, edit and delete services, locations and which towns a service covers."
		}
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
