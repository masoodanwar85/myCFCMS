/**
 * The admin landing screen.
 */
component extends="core.models.security.SecuredHandler" {

	property name="siteService" inject="SiteService@core";
	property name="userService" inject="UserService@core";
	property name="roleService" inject="RoleService@core";

	// Any signed-in user may see the dashboard; what it shows is filtered below.
	variables.openActions = "index";

	function index( event, rc, prc ){
		prc.pageTitle = "Dashboard";

		var siteId = prc.currentSite.getId();

		// Only count what this user is allowed to know about.
		prc.canSeeUsers = authorization.can( prc.currentUser, "users.view" );
		prc.canSeeRoles = authorization.can( prc.currentUser, "roles.view" );

		// Counted in the database rather than by fetching every user and
		// measuring the array, which is what this used to do.
		prc.userCount   = prc.canSeeUsers ? userService.countUsersForSite( siteId ) : 0;
		prc.roleCount   = prc.canSeeRoles ? roleService.getRolesForSite( siteId ).len() : 0;
		prc.domains     = siteService.getDomains( siteId );
		prc.permissions = authorization.getPermissionsFor( prc.currentUser );

		event.setView( view = "dashboard/index", module = "admin" );
	}

}
