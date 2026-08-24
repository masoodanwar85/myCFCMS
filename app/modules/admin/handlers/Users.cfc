/**
 * Managing the people who can sign in to this site.
 *
 * Every action is scoped to the current tenant. A user id arriving in the URL
 * is checked against the current site before anything is done with it — an id
 * is a guess anyone can make, and Group 2's isolation guarantees would mean
 * nothing if a handler acted on one without asking whose it is.
 */
component extends="core.models.security.SecuredHandler" {

	property name="userService" inject="UserService@core";
	property name="roleService" inject="RoleService@core";
	property name="paginator"   inject="Paginator@core";

	variables.permissions = {
		"index"  : "users.view",
		"new"    : "users.create",
		"create" : "users.create",
		"edit"   : "users.update",
		"update" : "users.update",
		"remove" : "users.delete",
		"$every" : "users.view"
	};

	function index( event, rc, prc ){
		prc.pageTitle  = "Users";

		prc.pagination = paginator.paginate(
			total   = userService.countUsersForSite( prc.currentSite.getId() ),
			page    = paginator.readPage( rc.page ?: 1 ),
			perPage = 25
		);
		prc.pageBase   = "/admin/users";
		prc.users      = userService.getUsersForSite(
			prc.currentSite.getId(), prc.pagination.perPage, prc.pagination.offset
		);
		prc.roleNames = {};

		for ( var user in prc.users ) {
			prc.roleNames[ user.getId() ] = userService
				.getRoles( user.getId() )
				.map( ( role ) => role.getName() );
		}

		prc.canCreate = authorization.can( prc.currentUser, "users.create" );
		prc.canUpdate = authorization.can( prc.currentUser, "users.update" );
		prc.canDelete = authorization.can( prc.currentUser, "users.delete" );

		event.setView( view = "users/index", module = "admin" );
	}

	function new( event, rc, prc ){
		prc.pageTitle = "New user";
		prc.user      = "";
		prc.roles     = roleService.getRolesForSite( prc.currentSite.getId() );
		prc.heldRoles = [];

		event.setView( view = "users/form", module = "admin" );
	}

	function create( event, rc, prc ){
		try {
			var user = userService.createUser(
				siteId   = prc.currentSite.getId(),
				name     = rc.name ?: "",
				email    = rc.email ?: "",
				password = rc.password ?: "",
				status   = rc.status ?: "active"
			);

			applyRoles( user.getId(), rc.roleIds ?: "" );
		} catch ( any e ) {
			return failBack( "/admin/users/new", e );
		}

		return done( "/admin/users", "User created." );
	}

	function edit( event, rc, prc ){
		var user = requireSiteUser( rc.id ?: 0, prc );

		prc.pageTitle = "Edit user";
		prc.user      = user;
		prc.roles     = roleService.getRolesForSite( prc.currentSite.getId() );
		prc.heldRoles = userService.getRoles( user.getId() ).map( ( role ) => role.getId() );

		event.setView( view = "users/form", module = "admin" );
	}

	function update( event, rc, prc ){
		var user = requireSiteUser( rc.id ?: 0, prc );

		try {
			userService.updateUser(
				userId = user.getId(),
				name   = rc.name ?: user.getName(),
				email  = rc.email ?: user.getEmail(),
				status = rc.status ?: user.getStatus()
			);

			// Blank means "leave it alone", so an edit does not require
			// retyping a password that is not changing.
			if ( len( rc.password ?: "" ) ) {
				userService.changePassword( user.getId(), rc.password );
			}

			applyRoles( user.getId(), rc.roleIds ?: "" );
		} catch ( any e ) {
			return failBack( "/admin/users/edit/" & user.getId(), e );
		}

		return done( "/admin/users", "User updated." );
	}

	function remove( event, rc, prc ){
		var user = requireSiteUser( rc.id ?: 0, prc );

		// Removing your own account would sign you out mid-action and could
		// leave a site with nobody able to administer it.
		if ( user.getId() == prc.currentUser.getId() ) {
			return done( "/admin/users", "You cannot delete your own account.", "error" );
		}

		userService.deleteUser( user.getId() );

		return done( "/admin/users", "User deleted." );
	}

	/**
	 * Replace a user's roles with the submitted set.
	 */
	private function applyRoles( required numeric userId, required string roleIds ){
		var wanted = listToArray( arguments.roleIds ).map( ( id ) => val( id ) );
		var held   = userService.getRoles( arguments.userId ).map( ( role ) => role.getId() );

		for ( var roleId in held ) {
			if ( !arrayContains( wanted, roleId ) ) {
				userService.removeRole( arguments.userId, roleId );
			}
		}

		for ( var roleId in wanted ) {
			if ( !arrayContains( held, roleId ) ) {
				userService.assignRole( arguments.userId, roleId );
			}
		}

		return this;
	}

	/**
	 * Load a user, refusing anything that is not this site's.
	 *
	 * A super admin is never editable from a tenant's admin: they belong to no
	 * site, so no site's staff should be able to change their account.
	 */
	private function requireSiteUser( required numeric userId, required struct prc ){
		var user = userService.getUserById( arguments.userId );

		if ( isNull( user ) || user.isSuperAdmin() || user.getSiteId() != arguments.prc.currentSite.getId() ) {
			throw(
				type    = "Admin.NotFoundHere",
				message = "No user [#arguments.userId#] on this site."
			);
		}

		return user;
	}

	private function failBack( required string uri, required any error ){
		return done( arguments.uri, arguments.error.message, "error" );
	}

}
