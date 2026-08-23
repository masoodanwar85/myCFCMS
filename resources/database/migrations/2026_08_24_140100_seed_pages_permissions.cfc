/**
 * Group 3 — the permissions the Pages module defines.
 *
 * A feature module registers its own capabilities into Core's global catalogue.
 * Core never learns what they mean; it only stores the slugs and lets each
 * site's roles grant them. This is the pattern every later module follows.
 *
 * Note what this migration does *not* do: it does not grant anything to any
 * role. Which roles get to publish is each client's decision, made through
 * RoleService. The one exception is the seeded `owner` role, which existing
 * sites can be brought up to date with via
 * `RoleService.seedDefaultRolesForSite()` — it is idempotent and will add the
 * newly registered slugs.
 */
component {

	variables.PERMISSIONS = [
		{ slug : "pages.view",    name : "View pages",    description : "See the site's pages, including drafts." },
		{ slug : "pages.create",  name : "Create pages",  description : "Add new pages to the site." },
		{ slug : "pages.update",  name : "Update pages",  description : "Edit page content, settings and position in the tree." },
		{ slug : "pages.delete",  name : "Delete pages",  description : "Remove pages from the site." },
		{ slug : "pages.publish", name : "Publish pages", description : "Make pages live, and take them down again." }
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

		// Grants in `role_permissions` follow via ON DELETE CASCADE.
		for ( var permission in variables.PERMISSIONS ) {
			queryExecute(
				"DELETE FROM `permissions` WHERE `slug` = :slug",
				{ slug : { value : permission.slug, cfsqltype : "cf_sql_varchar" } },
				options
			);
		}
	}

}
