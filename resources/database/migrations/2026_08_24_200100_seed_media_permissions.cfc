/**
 * Permissions the Media module defines.
 *
 * Uploading is separated from deleting: an editor usually needs to add images
 * without being able to remove one another page still points at.
 */
component {

	variables.PERMISSIONS = [
		{ slug : "media.view",   name : "View media",   description : "Browse the site's uploaded files." },
		{ slug : "media.upload", name : "Upload media", description : "Add files to the site's media library." },
		{ slug : "media.update", name : "Edit media",   description : "Change a file's alt text and title." },
		{ slug : "media.delete", name : "Delete media", description : "Permanently remove files, including any still in use." }
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
