/**
 * Role and permission administration, per site.
 *
 * Roles belong to a tenant, so every method here takes or derives a `siteId`
 * and no lookup is ever by slug alone.
 */
component singleton accessors="true" {

	property name="roleRepository"       inject="RoleRepository@core";
	property name="slugifier"        inject="Slugifier@core";
	property name="permissionRepository" inject="PermissionRepository@core";
	property name="siteRepository"       inject="SiteRepository@core";
	property name="wirebox"              inject="wirebox";

	/**
	 * The roles a newly provisioned site starts with.
	 *
	 * Two, deliberately. `owner` needs every Core permission or nobody can
	 * administer the new site at all. `editor` exists so there is a
	 * non-privileged role to hand out and so the multi-role model is actually
	 * exercised; feature modules will widen it with content permissions as they
	 * arrive. Anything more would be guessing at each client's org chart.
	 */
	variables.DEFAULT_ROLES = [
		{
			slug        : "owner",
			name        : "Owner",
			description : "Full control of this site.",
			// Resolved from the catalogue at seed time rather than listed here.
			// "Full control" has to keep meaning that as modules register new
			// capabilities; a hard-coded list would quietly stop being complete
			// the moment a module like Pages is installed.
			grantsEverything : true,
			permissions      : []
		},
		{
			slug        : "editor",
			name        : "Editor",
			description : "Day-to-day content work. Cannot change site configuration or access.",
			permissions : [ "site.view", "users.view", "roles.view" ]
		}
	];

	array function getDefaultRoleDefinitions(){
		return variables.DEFAULT_ROLES;
	}

	/**
	 * Give a site its starting roles.
	 *
	 * Provisioning a site is `SiteService.createSite()` followed by this call
	 * and then a first user. It is a separate step rather than a hook inside
	 * SiteService because tenancy has no business knowing that authorisation
	 * exists — the dependency runs one way, from access control towards
	 * tenancy, and not back.
	 *
	 * Idempotent: running it again leaves existing roles alone, but does
	 * re-apply their permission sets. That is how an existing site picks up
	 * capabilities registered by a newly installed module — re-run this and the
	 * owner role gains the new slugs.
	 *
	 * @return The site's roles after seeding.
	 */
	array function seedDefaultRolesForSite( required numeric siteId ){
		if ( isNull( siteRepository.findById( arguments.siteId ) ) ) {
			throw( type = "Auth.SiteNotFound", message = "No site with id [#arguments.siteId#]." );
		}

		for ( var definition in variables.DEFAULT_ROLES ) {
			var role = roleRepository.findBySlugForSite( definition.slug, arguments.siteId );

			if ( isNull( role ) ) {
				role = createRole(
					siteId      = arguments.siteId,
					name        = definition.name,
					slug        = definition.slug,
					description = definition.description
				);
			}

			var grantsAll = structKeyExists( definition, "grantsEverything" ) && definition.grantsEverything;

			var slugs = grantsAll
				? permissionRepository.findAll().map( ( permission ) => permission.getSlug() )
				: definition.permissions;

			grantPermissions( role.getId(), slugs );
		}

		return roleRepository.findBySiteId( arguments.siteId );
	}

	/**
	 * @throws Auth.SiteNotFound
	 * @throws Auth.InvalidRole
	 * @throws Auth.RoleSlugAlreadyTaken
	 */
	core.models.auth.Role function createRole(
		required numeric siteId,
		required string name,
		string slug        = "",
		string description = ""
	){
		if ( isNull( siteRepository.findById( arguments.siteId ) ) ) {
			throw( type = "Auth.SiteNotFound", message = "No site with id [#arguments.siteId#]." );
		}

		var roleName = trim( arguments.name );

		if ( !len( roleName ) ) {
			throw( type = "Auth.InvalidRole", message = "A role requires a name." );
		}

		var roleSlug = len( trim( arguments.slug ) ) ? slugify( arguments.slug ) : slugify( roleName );

		if ( !len( roleSlug ) ) {
			throw(
				type    = "Auth.InvalidRole",
				message = "Could not derive a usable slug from [#roleName#]. Provide one explicitly."
			);
		}

		if ( roleRepository.existsBySlugForSite( roleSlug, arguments.siteId ) ) {
			throw(
				type    = "Auth.RoleSlugAlreadyTaken",
				message = "The role slug [#roleSlug#] already exists for this site."
			);
		}

		var role = wirebox
			.getInstance( "Role@core" )
			.setSiteId( arguments.siteId )
			.setName( roleName )
			.setSlug( roleSlug )
			.setDescription( trim( arguments.description ) );

		return roleRepository.create( role );
	}

	/**
	 * @throws Auth.RoleNotFound
	 */
	core.models.auth.Role function updateRole(
		required numeric roleId,
		string name,
		string description
	){
		var role = requireRole( arguments.roleId );

		if ( !isNull( arguments.name ) ) {
			if ( !len( trim( arguments.name ) ) ) {
				throw( type = "Auth.InvalidRole", message = "A role requires a name." );
			}
			role.setName( trim( arguments.name ) );
		}

		if ( !isNull( arguments.description ) ) {
			role.setDescription( trim( arguments.description ) );
		}

		return roleRepository.update( role );
	}

	function deleteRole( required numeric roleId ){
		requireRole( arguments.roleId );
		roleRepository.delete( arguments.roleId );
		return this;
	}

	/* ---------------------------------------------------------------------
	 * Permissions on a role
	 * ------------------------------------------------------------------ */

	/**
	 * Grant one permission to a role.
	 *
	 * @throws Auth.RoleNotFound
	 * @throws Auth.PermissionNotFound when the slug is not in the catalogue.
	 */
	function grantPermission( required numeric roleId, required string permissionSlug ){
		requireRole( arguments.roleId );

		var permission = permissionRepository.findBySlug( arguments.permissionSlug );

		if ( isNull( permission ) ) {
			throw(
				type    = "Auth.PermissionNotFound",
				message = "[#arguments.permissionSlug#] is not a registered permission.",
				detail  = "Permissions are registered by migrations, not created at runtime."
			);
		}

		roleRepository.grantPermission( arguments.roleId, permission.getId() );

		return this;
	}

	/**
	 * Grant several permissions at once.
	 *
	 * Resolves every slug in one query, and refuses the whole batch if any slug
	 * is unknown — a partially applied role is harder to notice than a failed one.
	 *
	 * @throws Auth.PermissionNotFound
	 */
	function grantPermissions( required numeric roleId, required array permissionSlugs ){
		requireRole( arguments.roleId );

		var ids     = permissionRepository.findIdsBySlugs( arguments.permissionSlugs );
		var missing = arguments.permissionSlugs.filter( ( slug ) => !ids.keyExists( slug ) );

		if ( missing.len() ) {
			throw(
				type    = "Auth.PermissionNotFound",
				message = "Unregistered permissions: #missing.toList( ', ' )#.",
				detail  = "Permissions are registered by migrations, not created at runtime."
			);
		}

		for ( var slug in arguments.permissionSlugs ) {
			roleRepository.grantPermission( arguments.roleId, ids[ slug ] );
		}

		return this;
	}

	function revokePermission( required numeric roleId, required string permissionSlug ){
		requireRole( arguments.roleId );

		var permission = permissionRepository.findBySlug( arguments.permissionSlug );

		if ( !isNull( permission ) ) {
			roleRepository.revokePermission( arguments.roleId, permission.getId() );
		}

		return this;
	}

	/**
	 * Replace a role's permissions wholesale.
	 *
	 * Validates the new set before clearing the old one, so a bad slug leaves
	 * the role as it was rather than stripped.
	 */
	function syncPermissions( required numeric roleId, required array permissionSlugs ){
		requireRole( arguments.roleId );

		var ids     = permissionRepository.findIdsBySlugs( arguments.permissionSlugs );
		var missing = arguments.permissionSlugs.filter( ( slug ) => !ids.keyExists( slug ) );

		if ( missing.len() ) {
			throw(
				type    = "Auth.PermissionNotFound",
				message = "Unregistered permissions: #missing.toList( ', ' )#."
			);
		}

		roleRepository.revokeAllPermissions( arguments.roleId );

		for ( var slug in arguments.permissionSlugs ) {
			roleRepository.grantPermission( arguments.roleId, ids[ slug ] );
		}

		return this;
	}

	array function getPermissions( required numeric roleId ){
		return roleRepository.getPermissionSlugs( arguments.roleId );
	}

	/* ---------------------------------------------------------------------
	 * Reads
	 * ------------------------------------------------------------------ */

	function getRoleById( required numeric roleId ){
		return roleRepository.findById( arguments.roleId );
	}

	function getRoleBySlugForSite( required string slug, required numeric siteId ){
		return roleRepository.findBySlugForSite( arguments.slug, arguments.siteId );
	}

	array function getRolesForSite( required numeric siteId ){
		return roleRepository.findBySiteId( arguments.siteId );
	}

	array function getAllPermissions(){
		return permissionRepository.findAll();
	}

	string function slugify( required string value ){
		// Delegated: five copies of this each dropped accented
		// characters instead of transliterating them.
		return slugifier.slugify( arguments.value );
	}

	private function requireRole( required numeric roleId ){
		var role = roleRepository.findById( arguments.roleId );

		if ( isNull( role ) ) {
			throw( type = "Auth.RoleNotFound", message = "No role with id [#arguments.roleId#]." );
		}

		return role;
	}

}
