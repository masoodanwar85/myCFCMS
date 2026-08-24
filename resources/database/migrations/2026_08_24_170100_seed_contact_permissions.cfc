/**
 * Group 7 — the permissions the Contact module defines.
 *
 * Reading what visitors sent and configuring the form are separated: an
 * assistant may need to triage the inbox without being able to change where
 * enquiries are delivered.
 */
component {

	variables.PERMISSIONS = [
		{ slug : "contact.view",              name : "View enquiries",   description : "Read messages sent through the site's contact forms." },
		{ slug : "contact.manage",            name : "Manage forms",     description : "Create and configure contact forms, including where enquiries go." },
		{ slug : "contact.submissions.delete", name : "Delete enquiries", description : "Permanently remove submitted messages." }
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
