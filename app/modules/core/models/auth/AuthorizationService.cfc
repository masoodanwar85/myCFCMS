/**
 * The one place that answers "may this user do this?".
 *
 * Every check is two questions, in this order:
 *
 *   1. Does the user belong to the site the action targets?   (tenancy)
 *   2. Do their roles on that site grant the permission?      (authorisation)
 *
 * Both matter, and the first is the one that is easy to forget. A user holding
 * `users.delete` on their own site must not be able to delete users on another;
 * checking the permission alone would let them. So the site is always part of
 * the question, and it defaults to the tenant the current request resolved to.
 *
 * A super admin passes both questions everywhere, by definition.
 */
component singleton accessors="true" {

	property name="roleRepository" inject="RoleRepository@core";
	property name="tenantContext"  inject="TenantContext@core";

	/**
	 * May this user perform this action on this site?
	 *
	 * @user           The acting user.
	 * @permissionSlug e.g. `users.create`.
	 * @siteId         Defaults to the current request's tenant.
	 *
	 * @return false — never throws — so callers can branch on it directly.
	 *         Use `assertCan()` when the answer should stop the request.
	 */
	boolean function can(
		required core.models.auth.User user,
		required string permissionSlug,
		numeric siteId
	){
		if ( !arguments.user.isActive() ) {
			return false;
		}

		if ( arguments.user.isSuperAdmin() ) {
			return true;
		}

		var targetSiteId = resolveSiteId( argumentCollection = arguments );

		// No tenant in play and the user is not a super admin: nothing to
		// authorise against, so deny rather than guess.
		if ( isNull( targetSiteId ) ) {
			return false;
		}

		if ( !arguments.user.belongsToSite( targetSiteId ) ) {
			return false;
		}

		return arrayFindNoCase( getPermissionsFor( arguments.user ), arguments.permissionSlug ) > 0;
	}

	/**
	 * Inverse of `can`, for readability at call sites.
	 */
	boolean function cannot(
		required core.models.auth.User user,
		required string permissionSlug,
		numeric siteId
	){
		return !can( argumentCollection = arguments );
	}

	/**
	 * Enforce a permission.
	 *
	 * Named `assertCan` rather than `assert` to stay clear of engine built-ins.
	 *
	 * @throws Auth.NotAuthorized
	 */
	function assertCan(
		required core.models.auth.User user,
		required string permissionSlug,
		numeric siteId
	){
		if ( can( argumentCollection = arguments ) ) {
			return this;
		}

		throw(
			type    = "Auth.NotAuthorized",
			message = "User [#arguments.user.getId()#] may not [#arguments.permissionSlug#] here.",
			detail  = "Either the user does not belong to the target site, or no role of theirs grants it."
		);
	}

	/**
	 * Does the user hold every one of these permissions?
	 */
	boolean function canAll(
		required core.models.auth.User user,
		required array permissionSlugs,
		numeric siteId
	){
		for ( var slug in arguments.permissionSlugs ) {
			if ( !can( argumentCollection = checkArgs( arguments, slug ) ) ) {
				return false;
			}
		}

		return true;
	}

	/**
	 * Does the user hold at least one of these permissions?
	 */
	boolean function canAny(
		required core.models.auth.User user,
		required array permissionSlugs,
		numeric siteId
	){
		for ( var slug in arguments.permissionSlugs ) {
			if ( can( argumentCollection = checkArgs( arguments, slug ) ) ) {
				return true;
			}
		}

		return false;
	}

	/**
	 * Does the user hold this role on their own site?
	 */
	boolean function hasRole( required core.models.auth.User user, required string roleSlug ){
		if ( arguments.user.isSuperAdmin() ) {
			return false;
		}

		var wanted = arguments.roleSlug;

		for ( var role in roleRepository.findRolesForUser( arguments.user.getId() ) ) {
			if ( role.getSlug() == wanted ) {
				return true;
			}
		}

		return false;
	}

	/**
	 * Every permission slug this user holds.
	 *
	 * A super admin returns the empty array: they are not granted permissions,
	 * they bypass the check. Do not use this to decide authorisation — use
	 * `can()`, which handles that case.
	 */
	array function getPermissionsFor( required core.models.auth.User user ){
		if ( arguments.user.isSuperAdmin() ) {
			return [];
		}

		return roleRepository.findPermissionSlugsForUser( arguments.user.getId() );
	}

	/**
	 * Build a `can()` argument set, carrying `siteId` only when one was given.
	 */
	private struct function checkArgs( required struct source, required string permissionSlug ){
		var args = {
			user           : arguments.source.user,
			permissionSlug : arguments.permissionSlug
		};

		if ( !isNull( arguments.source.siteId ) ) {
			args.siteId = arguments.source.siteId;
		}

		return args;
	}

	/**
	 * The site an authorisation question is about.
	 *
	 * An explicit argument wins; otherwise the tenant this request resolved to.
	 * Returns null when neither is available, which `can()` treats as a denial.
	 */
	private function resolveSiteId(
		required core.models.auth.User user,
		required string permissionSlug,
		numeric siteId
	){
		if ( !isNull( arguments.siteId ) ) {
			return arguments.siteId;
		}

		if ( tenantContext.hasCurrentTenant() ) {
			return tenantContext.getCurrentTenantId();
		}

		return;
	}

}
