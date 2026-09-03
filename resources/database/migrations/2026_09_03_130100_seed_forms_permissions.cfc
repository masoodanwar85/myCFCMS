/**
 * The permissions the Forms module defines.
 *
 * Split the same way Contact's are, and for the same reason: reading what
 * people sent and changing where it goes are different jobs. An assistant may
 * need the inbox without being able to redirect responses to another address.
 */
component {

	variables.PERMISSIONS = [
		{ slug : "forms.view",               name : "View form responses", description : "Read responses sent through the site's forms." },
		{ slug : "forms.manage",             name : "Manage forms",        description : "Build forms and their fields, and set where responses go." },
		{ slug : "forms.submissions.delete", name : "Delete responses",    description : "Permanently remove submitted responses." }
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
