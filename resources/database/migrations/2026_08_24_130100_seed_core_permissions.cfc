/**
 * Group 2 — the permissions Core itself defines.
 *
 * Reference data rather than sample data: the authorisation code and the
 * default roles both refer to these slugs, so an empty catalogue is a broken
 * install, not merely an unseeded one. That is why this is a migration and not
 * a seeder — seeders are optional, and this is not.
 *
 * Feature modules will add their own slugs (`pages.publish`, `blog.create`, ...)
 * through their own migrations as they arrive.
 */
component {

	variables.PERMISSIONS = [
		// The tenant's own configuration
		{ slug : "site.view",            name : "View site",            description : "See the site's details and configuration." },
		{ slug : "site.update",          name : "Update site",          description : "Change the site's name, status, timezone and locale." },
		{ slug : "site.domains.manage",  name : "Manage domains",       description : "Add, remove and re-point the site's domains." },
		{ slug : "site.settings.manage", name : "Manage site settings", description : "Read and write the site's key/value settings." },

		// People
		{ slug : "users.view",           name : "View users",           description : "List and view users belonging to the site." },
		{ slug : "users.create",         name : "Create users",         description : "Add new users to the site." },
		{ slug : "users.update",         name : "Update users",         description : "Edit users, including resetting their passwords." },
		{ slug : "users.delete",         name : "Delete users",         description : "Remove users from the site." },

		// Access control
		{ slug : "roles.view",           name : "View roles",           description : "List and view the site's roles." },
		{ slug : "roles.create",         name : "Create roles",         description : "Define new roles for the site." },
		{ slug : "roles.update",         name : "Update roles",         description : "Edit roles and the permissions they grant." },
		{ slug : "roles.delete",         name : "Delete roles",         description : "Remove roles from the site." }
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

		// Only the slugs this migration introduced. Grants in `role_permissions`
		// follow via ON DELETE CASCADE.
		for ( var permission in variables.PERMISSIONS ) {
			queryExecute(
				"DELETE FROM `permissions` WHERE `slug` = :slug",
				{ slug : { value : permission.slug, cfsqltype : "cf_sql_varchar" } },
				options
			);
		}
	}

}
