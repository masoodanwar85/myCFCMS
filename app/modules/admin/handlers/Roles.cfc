/**
 * Managing this site's roles and what they grant.
 *
 * Roles are per-tenant (Group 2), so the permission catalogue shown here is
 * global but the roles composing it belong to one site.
 */
component extends="core.models.security.SecuredHandler" {

	property name="roleService" inject="RoleService@core";

	variables.permissions = {
		"index"  : "roles.view",
		"new"    : "roles.create",
		"create" : "roles.create",
		"edit"   : "roles.update",
		"update" : "roles.update",
		"remove" : "roles.delete",
		"$every" : "roles.view"
	};

	function index( event, rc, prc ){
		prc.pageTitle = "Roles";
		prc.roles     = roleService.getRolesForSite( prc.currentSite.getId() );
		prc.granted   = {};

		for ( var role in prc.roles ) {
			prc.granted[ role.getId() ] = roleService.getPermissions( role.getId() );
		}

		prc.canCreate = authorization.can( prc.currentUser, "roles.create" );
		prc.canUpdate = authorization.can( prc.currentUser, "roles.update" );
		prc.canDelete = authorization.can( prc.currentUser, "roles.delete" );

		event.setView( view = "roles/index", module = "admin" );
	}

	function new( event, rc, prc ){
		prc.pageTitle   = "New role";
		prc.role        = "";
		prc.permissions = roleService.getAllPermissions();
		prc.held        = [];

		event.setView( view = "roles/form", module = "admin" );
	}

	function create( event, rc, prc ){
		try {
			var role = roleService.createRole(
				siteId      = prc.currentSite.getId(),
				name        = rc.name ?: "",
				slug        = rc.slug ?: "",
				description = rc.description ?: ""
			);

			roleService.syncPermissions( role.getId(), listToArray( rc.permissionSlugs ?: "" ) );
		} catch ( any e ) {
			return done( "/admin/roles/new", e.message, "error" );
		}

		return done( "/admin/roles", "Role created." );
	}

	function edit( event, rc, prc ){
		var role = requireSiteRole( rc.id ?: 0, prc );

		prc.pageTitle   = "Edit role";
		prc.role        = role;
		prc.permissions = roleService.getAllPermissions();
		prc.held        = roleService.getPermissions( role.getId() );

		event.setView( view = "roles/form", module = "admin" );
	}

	function update( event, rc, prc ){
		var role = requireSiteRole( rc.id ?: 0, prc );

		try {
			roleService.updateRole(
				roleId      = role.getId(),
				name        = rc.name ?: role.getName(),
				description = rc.description ?: ""
			);

			roleService.syncPermissions( role.getId(), listToArray( rc.permissionSlugs ?: "" ) );
		} catch ( any e ) {
			return done( "/admin/roles/edit/" & role.getId(), e.message, "error" );
		}

		return done( "/admin/roles", "Role updated." );
	}

	function remove( event, rc, prc ){
		var role = requireSiteRole( rc.id ?: 0, prc );

		// Deleting the role you hold could remove your own ability to get back in.
		if ( authorization.hasRole( prc.currentUser, role.getSlug() ) ) {
			return done( "/admin/roles", "You cannot delete a role you currently hold.", "error" );
		}

		roleService.deleteRole( role.getId() );

		return done( "/admin/roles", "Role deleted." );
	}

	private function requireSiteRole( required numeric roleId, required struct prc ){
		var role = roleService.getRoleById( arguments.roleId );

		if ( isNull( role ) || role.getSiteId() != arguments.prc.currentSite.getId() ) {
			throw( type = "Admin.NotFoundHere", message = "No role [#arguments.roleId#] on this site." );
		}

		return role;
	}

}
