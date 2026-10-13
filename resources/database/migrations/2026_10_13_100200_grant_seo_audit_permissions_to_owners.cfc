/**
 * Give existing owner roles the SEO audit permissions.
 *
 * The seed migration only inserted the slugs. A site provisioned before that
 * still has an owner who holds "everything" except these two, so the SEO nav
 * item would stay hidden after the module loaded.
 *
 * Same backfill as FAQs: a role that already holds every other
 * permission is treated as meant to hold these too. Identified that way rather
 * than by the slug `owner`, so a renamed top role is still covered.
 */
component {

	variables.SLUGS = [ "seo.view", "seo.run" ];

	function up( schema, qb ){
		var options = arguments.schema.getDefaultOptions();
		var stamp   = now();

		for ( var slug in variables.SLUGS ) {
			queryExecute(
				"
				INSERT INTO `role_permissions` ( `role_id`, `permission_id`, `created_at` )
				SELECT r.`id`, p.`id`, :createdAt
				FROM `roles` r
				CROSS JOIN `permissions` p
				WHERE p.`slug` = :slug
				  AND NOT EXISTS (
				      SELECT 1 FROM `permissions` p2
				      WHERE p2.`slug` NOT IN ( :view, :runSlug )
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
					slug      : { value : slug, cfsqltype : "cf_sql_varchar" },
					view      : { value : "seo.view", cfsqltype : "cf_sql_varchar" },
					runSlug   : { value : "seo.run", cfsqltype : "cf_sql_varchar" },
					createdAt : { value : stamp, cfsqltype : "cf_sql_timestamp" }
				},
				options
			);
		}
	}

	function down( schema, qb ){
		var options = arguments.schema.getDefaultOptions();

		for ( var slug in variables.SLUGS ) {
			queryExecute(
				"
				DELETE rp FROM `role_permissions` rp
				INNER JOIN `permissions` p ON p.`id` = rp.`permission_id`
				WHERE p.`slug` = :slug
				",
				{ slug : { value : slug, cfsqltype : "cf_sql_varchar" } },
				options
			);
		}
	}

}
