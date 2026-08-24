/**
 * Permissions for the two Core areas added here.
 *
 * Both are site-configuration rather than content: an editor writes pages, but
 * deciding what appears in the site's navigation, or whether the site is open
 * to search engines at all, is the sort of change a client notices immediately
 * and everywhere.
 *
 * Unlike the earlier permission migrations, this one **backfills**. Those
 * relied on `owner` being resolved from the whole catalogue at seed time, which
 * is true for a site created afterwards and false for every site that already
 * exists. On an installation being upgraded, that left the owner of a live site
 * unable to reach a feature that had just been installed. Granting to roles
 * that already hold everything fixes that without inventing a new idea of what
 * "everything" means.
 */
component {

	variables.PERMISSIONS = [
		{ slug : "menus.manage", name : "Manage menus", description : "Create menus and decide what appears in the site's navigation." },
		{ slug : "seo.manage",   name : "Manage SEO",   description : "Change canonical addresses, search-engine visibility and social preview defaults." }
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

		for ( var permission in variables.PERMISSIONS ) {
			// Every role that already holds every *other* permission is, by
			// definition, a role meant to hold everything. Identifying it that
			// way rather than by the slug `owner` means a site that renamed or
			// replaced its top role is still covered.
			queryExecute(
				"
				INSERT INTO `role_permissions` ( `role_id`, `permission_id`, `created_at` )
				SELECT r.`id`, p.`id`, :createdAt
				FROM `roles` r
				CROSS JOIN `permissions` p
				WHERE p.`slug` = :slug
				  AND NOT EXISTS (
				      SELECT 1 FROM `permissions` p2
				      WHERE p2.`slug` NOT IN ( :menus, :seo )
				        AND NOT EXISTS (
				            SELECT 1 FROM `role_permissions` rp2
				            WHERE rp2.`role_id` = r.`id` AND rp2.`permission_id` = p2.`id`
				        )
				  )
				  AND NOT EXISTS (
				      SELECT 1 FROM `role_permissions` rp
				      WHERE rp.`role_id` = r.`id` AND rp.`permission_id` = p.`id`
				  )
				",
				{
					slug      : { value : permission.slug, cfsqltype : "cf_sql_varchar" },
					menus     : { value : "menus.manage", cfsqltype : "cf_sql_varchar" },
					seo       : { value : "seo.manage", cfsqltype : "cf_sql_varchar" },
					createdAt : { value : stamp, cfsqltype : "cf_sql_timestamp" }
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
