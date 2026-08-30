/**
 * Permissions the Will module defines.
 *
 * Reading submissions and deleting them are separated: an assistant may need
 * to triage the inbox without being able to remove a will. `will.manage` is
 * reserved for later configuration screens.
 *
 * This migration inserts slugs only. Existing owner roles pick them up in
 * `2026_08_28_100200_grant_will_permissions_to_owners`. New sites still get
 * them from `RoleService.seedDefaultRolesForSite()`.
 */
component {

	variables.PERMISSIONS = [
		{
			slug        : "will.view",
			name        : "View wills",
			description : "Read will questionnaire submissions for this site."
		},
		{
			slug        : "will.manage",
			name        : "Manage wills",
			description : "Update submission status and staff notes."
		},
		{
			slug        : "will.submissions.delete",
			name        : "Delete wills",
			description : "Permanently remove a will submission and its related records."
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
