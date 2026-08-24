/**
 * Persistence for tenant-scoped key/value settings.
 *
 * `(site_id, setting_key)` is unique, so writes are an upsert: callers set a
 * key without caring whether it already existed.
 */
component singleton extends="core.models.persistence.BaseRepository" {

	variables.TABLE   = "site_settings";
	variables.COLUMNS = [
		"id",
		"site_id",
		"setting_key",
		"setting_value",
		"created_at",
		"updated_at"
	];

	/**
	 * Create or overwrite one setting.
	 *
	 * @return The persisted SiteSetting.
	 */
	core.models.tenancy.SiteSetting function put(
		required numeric siteId,
		required string key,
		string value = ""
	){
		var stamp    = now();
		var existing = findByKey( arguments.siteId, arguments.key );

		if ( isNull( existing ) ) {
			var result = variables.query
				.from( variables.TABLE )
				.insert( {
					"site_id"       : arguments.siteId,
					"setting_key"   : arguments.key,
					"setting_value" : { value : arguments.value, cfsqltype : "cf_sql_longvarchar" },
					"created_at"    : { value : stamp, cfsqltype : "cf_sql_timestamp" },
					"updated_at"    : { value : stamp, cfsqltype : "cf_sql_timestamp" }
				} );

			return wirebox
				.getInstance( "SiteSetting@core" )
				.setId( generatedKey( result, variables.TABLE ) )
				.setSiteId( arguments.siteId )
				.setSettingKey( arguments.key )
				.setSettingValue( arguments.value )
				.setCreatedAt( stamp )
				.setUpdatedAt( stamp );
		}

		variables.query
			.from( variables.TABLE )
			.where( "id", existing.getId() )
			.update( {
				"setting_value" : { value : arguments.value, cfsqltype : "cf_sql_longvarchar" },
				"updated_at"    : { value : stamp, cfsqltype : "cf_sql_timestamp" }
			} );

		return existing.setSettingValue( arguments.value ).setUpdatedAt( stamp );
	}

	/**
	 * Named `findByKey` rather than `find`: an unqualified call to a method
	 * named `find` resolves to CFML's built-in string function, not to this one.
	 *
	 * @return SiteSetting, or null when the key is not set for that site.
	 */
	function findByKey( required numeric siteId, required string key ){
		var row = variables.query
			.from( variables.TABLE )
			.select( variables.COLUMNS )
			.where( "site_id", arguments.siteId )
			.where( "setting_key", arguments.key )
			.first();

		if ( row.isEmpty() ) {
			return;
		}

		return toSetting( row );
	}

	/**
	 * Read a single value.
	 *
	 * @defaultValue Returned when the key is not set for that site.
	 */
	string function getValue(
		required numeric siteId,
		required string key,
		string defaultValue = ""
	){
		var setting = findByKey( arguments.siteId, arguments.key );
		if ( isNull( setting ) ) {
			return arguments.defaultValue;
		}

		// Not `?: ""`. ColdFusion's elvis operator falls through on any *falsy*
		// value, not just null — so a stored "false" or "0" came back as an
		// empty string, and every caller then read it as "not set". A setting
		// whose whole job is to hold a boolean could not be turned off.
		var stored = setting.getSettingValue();

		return isNull( stored ) ? "" : stored;
	}

	/**
	 * Every setting for a site, as a `{ key : value }` struct.
	 *
	 * One query rather than one per key, because callers that need settings
	 * usually need several of them.
	 */
	struct function getAllForSite( required numeric siteId ){
		var settings = {};

		variables.query
			.from( variables.TABLE )
			.select( [ "setting_key", "setting_value" ] )
			.where( "site_id", arguments.siteId )
			.get()
			.each( ( row ) => {
				// Same reason as getValue(): "false" and "0" are values, not
				// absences.
				settings[ row.setting_key ] = isNull( row.setting_value ) ? "" : row.setting_value;
			} );

		return settings;
	}

	function delete( required numeric siteId, required string key ){
		variables.query
			.from( variables.TABLE )
			.where( "site_id", arguments.siteId )
			.where( "setting_key", arguments.key )
			.delete();

		return this;
	}

	core.models.tenancy.SiteSetting function toSetting( required struct row ){
		return wirebox
			.getInstance( "SiteSetting@core" )
			.setId( arguments.row.id )
			.setSiteId( arguments.row.site_id )
			.setSettingKey( arguments.row.setting_key )
			.setSettingValue( isNull( arguments.row.setting_value ) ? "" : arguments.row.setting_value )
			.setCreatedAt( arguments.row.created_at )
			.setUpdatedAt( arguments.row.updated_at );
	}

}
