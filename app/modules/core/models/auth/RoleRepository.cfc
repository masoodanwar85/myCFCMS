/**
 * Persistence for per-site roles, and for the grants that connect a role to
 * permissions and a user to roles.
 *
 * The join tables live here rather than in repositories of their own: neither
 * has an identity or a lifecycle beyond the role it hangs off, and splitting
 * them would buy nothing but indirection.
 */
component singleton extends="core.models.persistence.BaseRepository" {

	variables.TABLE   = "roles";
	variables.COLUMNS = [
		"id",
		"site_id",
		"name",
		"slug",
		"description",
		"created_at",
		"updated_at"
	];

	/**
	 * @throws Auth.RoleSlugAlreadyTaken when the site already has that slug.
	 */
	core.models.auth.Role function create( required core.models.auth.Role role ){
		var stamp  = now();
		var result = "";

		try {
			result = variables.query
				.from( variables.TABLE )
				.insert( {
					"site_id"     : arguments.role.getSiteId(),
					"name"        : arguments.role.getName(),
					"slug"        : arguments.role.getSlug(),
					"description" : arguments.role.getDescription() ?: "",
					"created_at"  : { value : stamp, cfsqltype : "cf_sql_timestamp" },
					"updated_at"  : { value : stamp, cfsqltype : "cf_sql_timestamp" }
				} );
		} catch ( any e ) {
			if ( !isUniqueViolation( e ) ) {
				rethrow;
			}
			throw(
				type    = "Auth.RoleSlugAlreadyTaken",
				message = "The role slug [#arguments.role.getSlug()#] already exists for this site.",
				detail  = e.message
			);
		}

		arguments.role.setId( generatedKey( result, variables.TABLE ) );
		arguments.role.setCreatedAt( stamp );
		arguments.role.setUpdatedAt( stamp );

		return arguments.role;
	}

	core.models.auth.Role function update( required core.models.auth.Role role ){
		var stamp = now();

		variables.query
			.from( variables.TABLE )
			.where( "id", arguments.role.getId() )
			.update( {
				"name"        : arguments.role.getName(),
				"description" : arguments.role.getDescription() ?: "",
				"updated_at"  : { value : stamp, cfsqltype : "cf_sql_timestamp" }
			} );

		arguments.role.setUpdatedAt( stamp );

		return arguments.role;
	}

	function findById( required numeric id ){
		return toRoleOrNull(
			variables.query
				.from( variables.TABLE )
				.select( variables.COLUMNS )
				.where( "id", arguments.id )
				.first()
		);
	}

	/**
	 * Roles are addressed by slug *within a site*, never by slug alone.
	 */
	function findBySlugForSite( required string slug, required numeric siteId ){
		return toRoleOrNull(
			variables.query
				.from( variables.TABLE )
				.select( variables.COLUMNS )
				.where( "slug", arguments.slug )
				.where( "site_id", arguments.siteId )
				.first()
		);
	}

	boolean function existsBySlugForSite( required string slug, required numeric siteId ){
		return variables.query
			.from( variables.TABLE )
			.where( "slug", arguments.slug )
			.where( "site_id", arguments.siteId )
			.exists();
	}

	array function findBySiteId( required numeric siteId ){
		return variables.query
			.from( variables.TABLE )
			.select( variables.COLUMNS )
			.where( "site_id", arguments.siteId )
			.orderBy( "name" )
			.get()
			.map( ( row ) => toRole( row ) );
	}

	function delete( required numeric roleId ){
		variables.query.from( variables.TABLE ).where( "id", arguments.roleId ).delete();
		return this;
	}

	/* ---------------------------------------------------------------------
	 * Role -> permission grants
	 * ------------------------------------------------------------------ */

	/**
	 * Grant a permission to a role. Idempotent: the composite primary key makes
	 * a repeat grant a no-op rather than an error.
	 */
	function grantPermission( required numeric roleId, required numeric permissionId ){
		if ( hasPermissionGrant( arguments.roleId, arguments.permissionId ) ) {
			return this;
		}

		try {
			variables.query
				.from( "role_permissions" )
				.insert( {
					"role_id"       : arguments.roleId,
					"permission_id" : arguments.permissionId,
					"created_at"    : { value : now(), cfsqltype : "cf_sql_timestamp" }
				} );
		} catch ( any e ) {
			// Two callers granting at once: the second is still the desired state.
			if ( !isUniqueViolation( e ) ) {
				rethrow;
			}
		}

		return this;
	}

	boolean function hasPermissionGrant( required numeric roleId, required numeric permissionId ){
		return variables.query
			.from( "role_permissions" )
			.where( "role_id", arguments.roleId )
			.where( "permission_id", arguments.permissionId )
			.exists();
	}

	function revokePermission( required numeric roleId, required numeric permissionId ){
		variables.query
			.from( "role_permissions" )
			.where( "role_id", arguments.roleId )
			.where( "permission_id", arguments.permissionId )
			.delete();

		return this;
	}

	function revokeAllPermissions( required numeric roleId ){
		variables.query.from( "role_permissions" ).where( "role_id", arguments.roleId ).delete();
		return this;
	}

	/**
	 * @return An array of permission slugs the role grants.
	 */
	array function getPermissionSlugs( required numeric roleId ){
		return variables.query
			.from( "role_permissions AS rp" )
			.join( "permissions AS p", "p.id", "rp.permission_id" )
			.select( [ "p.slug" ] )
			.where( "rp.role_id", arguments.roleId )
			.orderBy( "p.slug" )
			.get()
			.map( ( row ) => row.slug );
	}

	/* ---------------------------------------------------------------------
	 * User -> role assignments
	 * ------------------------------------------------------------------ */

	/**
	 * Assign a role to a user.
	 *
	 * `site_id` is written alongside so the composite foreign keys can check
	 * that the user and the role belong to the same site. A mismatch is
	 * rejected by the database.
	 *
	 * @throws Auth.CrossTenantRoleAssignment when user and role are not on the same site.
	 */
	function assignRoleToUser(
		required numeric userId,
		required numeric roleId,
		required numeric siteId
	){
		if ( hasRoleAssignment( arguments.userId, arguments.roleId ) ) {
			return this;
		}

		try {
			variables.query
				.from( "user_roles" )
				.insert( {
					"user_id"    : arguments.userId,
					"role_id"    : arguments.roleId,
					"site_id"    : arguments.siteId,
					"created_at" : { value : now(), cfsqltype : "cf_sql_timestamp" }
				} );
		} catch ( any e ) {
			// Deliberately a plain INSERT, not INSERT IGNORE: MySQL downgrades a
			// foreign key violation to a warning under IGNORE, which would turn a
			// cross-tenant assignment into a silent no-op instead of an error.
			if ( isForeignKeyViolation( e ) ) {
				throw(
					type    = "Auth.CrossTenantRoleAssignment",
					message = "User [#arguments.userId#] and role [#arguments.roleId#] do not both belong to site [#arguments.siteId#].",
					detail  = e.message
				);
			}
			if ( !isUniqueViolation( e ) ) {
				rethrow;
			}
		}

		return this;
	}

	boolean function hasRoleAssignment( required numeric userId, required numeric roleId ){
		return variables.query
			.from( "user_roles" )
			.where( "user_id", arguments.userId )
			.where( "role_id", arguments.roleId )
			.exists();
	}

	function removeRoleFromUser( required numeric userId, required numeric roleId ){
		variables.query
			.from( "user_roles" )
			.where( "user_id", arguments.userId )
			.where( "role_id", arguments.roleId )
			.delete();

		return this;
	}

	array function findRolesForUser( required numeric userId ){
		return variables.query
			.from( "user_roles AS ur" )
			.join( "roles AS r", "r.id", "ur.role_id" )
			.select( variables.COLUMNS.map( ( c ) => "r.#c#" ) )
			.where( "ur.user_id", arguments.userId )
			.orderBy( "r.name" )
			.get()
			.map( ( row ) => toRole( row ) );
	}

	/**
	 * Every permission slug a user holds, through every role they have.
	 *
	 * One query rather than a role fetch followed by a permission fetch per
	 * role, because this runs on authorisation checks.
	 */
	array function findPermissionSlugsForUser( required numeric userId ){
		return variables.query
			.from( "user_roles AS ur" )
			.join( "role_permissions AS rp", "rp.role_id", "ur.role_id" )
			.join( "permissions AS p", "p.id", "rp.permission_id" )
			.select( [ "p.slug" ] )
			.distinct()
			.where( "ur.user_id", arguments.userId )
			.orderBy( "p.slug" )
			.get()
			.map( ( row ) => row.slug );
	}

	core.models.auth.Role function toRole( required struct row ){
		return wirebox
			.getInstance( "Role@core" )
			.setId( arguments.row.id )
			.setSiteId( arguments.row.site_id )
			.setName( arguments.row.name )
			.setSlug( arguments.row.slug )
			.setDescription( arguments.row.description ?: "" )
			.setCreatedAt( arguments.row.created_at )
			.setUpdatedAt( arguments.row.updated_at );
	}

	private function toRoleOrNull( required struct row ){
		if ( arguments.row.isEmpty() ) {
			return;
		}
		return toRole( arguments.row );
	}

}
