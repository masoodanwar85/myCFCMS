/**
 * Give existing owner roles the Forms permissions.
 *
 * `2026_09_03_130100_seed_forms_permissions` only inserted the slugs. A site
 * provisioned before that still has an owner who holds "everything" except
 * these three, so the Forms nav item would stay hidden after the module loaded.
 *
 * Same backfill as menus/SEO and API: a role that already holds every other
 * permission is treated as meant to hold these too. Identified that way rather
 * than by the slug `owner`, so a renamed top role is still covered.
 */
component {

	variables.SLUGS = [ "forms.view", "forms.manage", "forms.submissions.delete" ];

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
				      WHERE p2.`slug` NOT IN ( :view, :manage, :delete )
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
					view      : { value : "forms.view", cfsqltype : "cf_sql_varchar" },
					manage    : { value : "forms.manage", cfsqltype : "cf_sql_varchar" },
					delete    : { value : "forms.submissions.delete", cfsqltype : "cf_sql_varchar" },
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
