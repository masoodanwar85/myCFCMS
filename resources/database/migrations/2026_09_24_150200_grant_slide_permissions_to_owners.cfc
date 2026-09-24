/**
 * Give existing owner roles the Slides permissions.
 */
component {

	variables.SLUGS = [ "slides.view", "slides.manage" ];

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
				      WHERE p2.`slug` NOT IN ( :view, :manage )
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
					view      : { value : "slides.view", cfsqltype : "cf_sql_varchar" },
					manage    : { value : "slides.manage", cfsqltype : "cf_sql_varchar" },
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
