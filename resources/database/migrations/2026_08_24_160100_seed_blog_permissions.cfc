/**
 * Group 6 — the permissions the Blog module defines.
 *
 * Registered by the module's own migration into Core's global catalogue,
 * exactly as Pages does. Core stores the slugs without knowing what they mean.
 */
component {

	variables.PERMISSIONS = [
		{ slug : "blog.view",    name : "View posts",    description : "See the site's blog posts, including drafts." },
		{ slug : "blog.create",  name : "Create posts",  description : "Write new blog posts." },
		{ slug : "blog.update",  name : "Update posts",  description : "Edit blog posts and their categories." },
		{ slug : "blog.delete",  name : "Delete posts",  description : "Remove blog posts." },
		{ slug : "blog.publish", name : "Publish posts", description : "Make posts live, and take them down again." },
		{ slug : "blog.categories.manage", name : "Manage categories", description : "Create, rename and remove blog categories." }
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
