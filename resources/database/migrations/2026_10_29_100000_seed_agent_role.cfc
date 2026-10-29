/**
 * Give every existing site the `agent` role.
 *
 * The definition lives in `RoleService.DEFAULT_ROLES`, so every site
 * provisioned from now on gets this role when `seedDefaultRolesForSite` runs.
 * Sites that already exist were seeded before the definition existed, so they
 * need the backfill — the same pattern as the `grant_*_permissions_to_owners`
 * migrations, and for the same reason.
 *
 * Raw SQL rather than calling `RoleService`: a migration runs through
 * CommandBox with no application context, so WireBox is not available to it.
 * That means the permission list is stated in two places, which is the one real
 * cost here — `AgentRoleSpec` asserts the two agree, so they cannot drift
 * silently.
 *
 * Creating the role does **not** create a user or a token. Those are deliberate
 * manual steps: an automated client that appears on a site because a migration
 * ran is exactly the thing nobody wants.
 */
component {

	variables.SLUG        = "agent";
	variables.NAME        = "Agent";
	variables.DESCRIPTION = "An automated client working through the API. Can draft, edit and publish content, upload media and run SEO audits. Cannot delete anything, post raw HTML, or change access or configuration.";

	// Must match `RoleService.DEFAULT_ROLES`. See the comment there for why
	// each of these is present and, more importantly, what is left out.
	variables.PERMISSIONS = [
		"site.view",
		"pages.view",
		"pages.create",
		"pages.update",
		"pages.publish",
		"media.view",
		"media.upload",
		"seo.view",
		"seo.run"
	];

	function up( schema, qb ){
		var options = arguments.schema.getDefaultOptions();
		var stamp   = now();

		// One role per site that has not got one. `NOT EXISTS` rather than
		// `INSERT IGNORE`: the unique key is `(site_id, slug)`, and relying on
		// a swallowed duplicate-key error to mean "already there" also swallows
		// every other integrity error.
		queryExecute(
			"
			INSERT INTO `roles` ( `site_id`, `name`, `slug`, `description`, `created_at`, `updated_at` )
			SELECT s.`id`, :name, :slug, :description, :createdAt, :updatedAt
			FROM `sites` s
			WHERE NOT EXISTS (
			    SELECT 1 FROM `roles` r
			    WHERE r.`site_id` = s.`id` AND r.`slug` = :slug
			)
			",
			{
				slug        : { value : variables.SLUG, cfsqltype : "cf_sql_varchar" },
				name        : { value : variables.NAME, cfsqltype : "cf_sql_varchar" },
				description : { value : variables.DESCRIPTION, cfsqltype : "cf_sql_varchar" },
				createdAt   : { value : stamp, cfsqltype : "cf_sql_timestamp" },
				updatedAt   : { value : stamp, cfsqltype : "cf_sql_timestamp" }
			},
			options
		);

		// Then the grants, for every agent role on every site — including one
		// that already existed, so re-running this picks up a permission added
		// to the list above. Idempotent, like the role insert.
		for ( var permission in variables.PERMISSIONS ) {
			queryExecute(
				"
				INSERT INTO `role_permissions` ( `role_id`, `permission_id`, `created_at` )
				SELECT r.`id`, p.`id`, :createdAt
				FROM `roles` r
				CROSS JOIN `permissions` p
				WHERE r.`slug` = :slug
				  AND p.`slug` = :permission
				  AND NOT EXISTS (
				      SELECT 1 FROM `role_permissions` rp
				      WHERE rp.`role_id` = r.`id` AND rp.`permission_id` = p.`id`
				  )
				",
				{
					slug       : { value : variables.SLUG, cfsqltype : "cf_sql_varchar" },
					permission : { value : permission, cfsqltype : "cf_sql_varchar" },
					createdAt  : { value : stamp, cfsqltype : "cf_sql_timestamp" }
				},
				options
			);
		}
	}

	/**
	 * Removes the role, and with it the grants and any assignment to a user —
	 * both cascade from `roles`.
	 *
	 * This deletes *any* role whose slug is `agent`, including one somebody
	 * created by hand. There is no way to tell the two apart, and leaving a
	 * half-reverted migration behind is worse.
	 */
	function down( schema, qb ){
		queryExecute(
			"DELETE FROM `roles` WHERE `slug` = :slug",
			{ slug : { value : variables.SLUG, cfsqltype : "cf_sql_varchar" } },
			arguments.schema.getDefaultOptions()
		);
	}

}
