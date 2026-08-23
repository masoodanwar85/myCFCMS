/**
 * Persistence for users.
 *
 * Every read that is not explicitly about the super admin is scoped by
 * `site_id`. Tenant scoping is not optional here — an unscoped user lookup is
 * how one client ends up administering another's site.
 */
component singleton extends="core.models.persistence.BaseRepository" {

	variables.TABLE   = "users";
	variables.COLUMNS = [
		"id",
		"site_id",
		"name",
		"email",
		"password_hash",
		"status",
		"created_at",
		"updated_at"
	];

	/**
	 * @user A populated, unsaved User. A null siteId creates a super admin.
	 *
	 * @throws Auth.EmailAlreadyTaken when the address is in use within that scope.
	 */
	core.models.auth.User function create( required core.models.auth.User user ){
		var stamp  = now();
		var result = "";

		try {
			result = variables.query
				.from( variables.TABLE )
				.insert( {
					"site_id"       : siteIdParam( arguments.user.getSiteId() ),
					"name"          : arguments.user.getName(),
					"email"         : arguments.user.getEmail(),
					"password_hash" : arguments.user.getPasswordHash(),
					"status"        : arguments.user.getStatus(),
					"created_at"    : { value : stamp, cfsqltype : "cf_sql_timestamp" },
					"updated_at"    : { value : stamp, cfsqltype : "cf_sql_timestamp" }
				} );
		} catch ( any e ) {
			// Guards the race the service's pre-check cannot cover.
			if ( !isUniqueViolation( e ) ) {
				rethrow;
			}
			throw(
				type    = "Auth.EmailAlreadyTaken",
				message = "The email [#arguments.user.getEmail()#] is already registered for this site.",
				detail  = e.message
			);
		}

		arguments.user.setId( generatedKey( result, variables.TABLE ) );
		arguments.user.setCreatedAt( stamp );
		arguments.user.setUpdatedAt( stamp );

		return arguments.user;
	}

	core.models.auth.User function update( required core.models.auth.User user ){
		var stamp = now();

		variables.query
			.from( variables.TABLE )
			.where( "id", arguments.user.getId() )
			.update( {
				"name"       : arguments.user.getName(),
				"email"      : arguments.user.getEmail(),
				"status"     : arguments.user.getStatus(),
				"updated_at" : { value : stamp, cfsqltype : "cf_sql_timestamp" }
			} );

		arguments.user.setUpdatedAt( stamp );

		return arguments.user;
	}

	/**
	 * Replace a user's password hash.
	 *
	 * Separate from `update` so a hash can never be changed as a side effect of
	 * editing a profile, and so the hash is not carried around in entity state
	 * during ordinary edits.
	 */
	function updatePasswordHash( required numeric userId, required string passwordHash ){
		variables.query
			.from( variables.TABLE )
			.where( "id", arguments.userId )
			.update( {
				"password_hash" : arguments.passwordHash,
				"updated_at"    : { value : now(), cfsqltype : "cf_sql_timestamp" }
			} );

		return this;
	}

	/**
	 * @return User, or null.
	 */
	function findById( required numeric id ){
		return toUserOrNull(
			variables.query
				.from( variables.TABLE )
				.select( variables.COLUMNS )
				.where( "id", arguments.id )
				.first()
		);
	}

	/**
	 * Look up a user within one site.
	 *
	 * @return User, or null when no such user belongs to that site.
	 */
	function findByEmailForSite( required string email, required numeric siteId ){
		return toUserOrNull(
			variables.query
				.from( variables.TABLE )
				.select( variables.COLUMNS )
				.where( "email", arguments.email )
				.where( "site_id", arguments.siteId )
				.first()
		);
	}

	/**
	 * Look up a platform super admin, who belongs to no site.
	 *
	 * @return User, or null.
	 */
	function findSuperAdminByEmail( required string email ){
		return toUserOrNull(
			variables.query
				.from( variables.TABLE )
				.select( variables.COLUMNS )
				.where( "email", arguments.email )
				.whereNull( "site_id" )
				.first()
		);
	}

	/**
	 * Is this address already taken in the given scope?
	 *
	 * @siteId Omit for the super-admin scope.
	 */
	boolean function existsByEmailInScope( required string email, siteId ){
		var q = variables.query.from( variables.TABLE ).where( "email", arguments.email );

		if ( isNull( arguments.siteId ) ) {
			q.whereNull( "site_id" );
		} else {
			q.where( "site_id", arguments.siteId );
		}

		return q.exists();
	}

	array function findBySiteId( required numeric siteId ){
		return variables.query
			.from( variables.TABLE )
			.select( variables.COLUMNS )
			.where( "site_id", arguments.siteId )
			.orderBy( "name" )
			.get()
			.map( ( row ) => toUser( row ) );
	}

	array function findSuperAdmins(){
		return variables.query
			.from( variables.TABLE )
			.select( variables.COLUMNS )
			.whereNull( "site_id" )
			.orderBy( "name" )
			.get()
			.map( ( row ) => toUser( row ) );
	}

	function delete( required numeric userId ){
		variables.query.from( variables.TABLE ).where( "id", arguments.userId ).delete();
		return this;
	}

	core.models.auth.User function toUser( required struct row ){
		var user = wirebox
			.getInstance( "User@core" )
			.setId( arguments.row.id )
			.setName( arguments.row.name )
			.setEmail( arguments.row.email )
			.setPasswordHash( arguments.row.password_hash )
			.setStatus( arguments.row.status )
			.setCreatedAt( arguments.row.created_at )
			.setUpdatedAt( arguments.row.updated_at );

		// Left unset for a super admin, so `isSuperAdmin()` stays true.
		if ( !isNull( arguments.row.site_id ) && len( arguments.row.site_id ) ) {
			user.setSiteId( arguments.row.site_id );
		}

		return user;
	}

	private function toUserOrNull( required struct row ){
		if ( arguments.row.isEmpty() ) {
			return;
		}
		return toUser( arguments.row );
	}

	/**
	 * A super admin's `site_id` must reach the database as a real NULL, not as
	 * an empty string, or the foreign key rejects it.
	 */
	private struct function siteIdParam( siteId ){
		return {
			value     : isNull( arguments.siteId ) ? "" : arguments.siteId,
			cfsqltype : "cf_sql_bigint",
			null      : isNull( arguments.siteId )
		};
	}

}
