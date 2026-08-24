/**
 * User administration.
 *
 * Validates, normalises and orchestrates; renders nothing and knows no HTTP, so
 * the same calls back an admin screen, a REST endpoint and a future GraphQL
 * mutation.
 *
 * Every method that takes a `siteId` means it: a user is created within a site,
 * found within a site, listed within a site. The only unscoped path is the
 * deliberate super-admin one, which is named as such.
 */
component singleton accessors="true" {

	property name="userRepository"  inject="UserRepository@core";
	property name="roleRepository"  inject="RoleRepository@core";
	property name="siteRepository"  inject="SiteRepository@core";
	property name="passwordService" inject="PasswordService@core";
	property name="wirebox"         inject="wirebox";

	/**
	 * Create a user belonging to one site.
	 *
	 * @siteId   The owning site.
	 * @name     Display name.
	 * @email    Login identifier, unique within the site.
	 * @password Plain text; hashed here and never stored or logged as given.
	 * @status   `active` or `inactive`.
	 *
	 * @throws Auth.SiteNotFound
	 * @throws Auth.InvalidUser
	 * @throws Auth.EmailAlreadyTaken
	 * @throws Auth.WeakPassword
	 */
	core.models.auth.User function createUser(
		required numeric siteId,
		required string name,
		required string email,
		required string password,
		string status = "active"
	){
		if ( isNull( siteRepository.findById( arguments.siteId ) ) ) {
			throw( type = "Auth.SiteNotFound", message = "No site with id [#arguments.siteId#]." );
		}

		var emailAddress = normalizeEmail( arguments.email );
		validateUserInput( arguments.name, emailAddress, arguments.status );

		if ( userRepository.existsByEmailInScope( emailAddress, arguments.siteId ) ) {
			throw(
				type    = "Auth.EmailAlreadyTaken",
				message = "The email [#emailAddress#] is already registered for this site."
			);
		}

		var user = wirebox
			.getInstance( "User@core" )
			.setSiteId( arguments.siteId )
			.setName( trim( arguments.name ) )
			.setEmail( emailAddress )
			.setPasswordHash( passwordService.hashPassword( arguments.password ) )
			.setStatus( arguments.status );

		return userRepository.create( user );
	}

	/**
	 * Create a platform super admin, who belongs to no site and reaches all of
	 * them.
	 *
	 * Separate from `createUser` on purpose. Granting cross-tenant reach should
	 * be an explicit call that reads as what it is, not a nullable argument
	 * someone can pass by accident.
	 *
	 * @throws Auth.EmailAlreadyTaken when another super admin uses that address.
	 */
	core.models.auth.User function createSuperAdmin(
		required string name,
		required string email,
		required string password,
		string status = "active"
	){
		var emailAddress = normalizeEmail( arguments.email );
		validateUserInput( arguments.name, emailAddress, arguments.status );

		if ( userRepository.existsByEmailInScope( emailAddress ) ) {
			throw(
				type    = "Auth.EmailAlreadyTaken",
				message = "The email [#emailAddress#] is already registered as a super admin."
			);
		}

		// siteId is left unset — that absence is what makes this a super admin.
		var user = wirebox
			.getInstance( "User@core" )
			.setName( trim( arguments.name ) )
			.setEmail( emailAddress )
			.setPasswordHash( passwordService.hashPassword( arguments.password ) )
			.setStatus( arguments.status );

		return userRepository.create( user );
	}

	/**
	 * @throws Auth.UserNotFound
	 * @throws Auth.InvalidUser
	 */
	core.models.auth.User function updateUser(
		required numeric userId,
		string name,
		string email,
		string status
	){
		var user = requireUser( arguments.userId );

		if ( !isNull( arguments.name ) ) {
			user.setName( trim( arguments.name ) );
		}

		if ( !isNull( arguments.email ) ) {
			var emailAddress = normalizeEmail( arguments.email );

			if ( emailAddress != user.getEmail() ) {
				var taken = user.isSuperAdmin()
					? userRepository.existsByEmailInScope( emailAddress )
					: userRepository.existsByEmailInScope( emailAddress, user.getSiteId() );

				if ( taken ) {
					throw(
						type    = "Auth.EmailAlreadyTaken",
						message = "The email [#emailAddress#] is already registered in this scope."
					);
				}
			}

			user.setEmail( emailAddress );
		}

		if ( !isNull( arguments.status ) ) {
			if ( !isValidStatus( arguments.status ) ) {
				throw(
					type    = "Auth.InvalidUser",
					message = "Unknown user status [#arguments.status#]. Expected `active` or `inactive`."
				);
			}
			user.setStatus( arguments.status );
		}

		validateUserInput( user.getName(), user.getEmail(), user.getStatus() );

		return userRepository.update( user );
	}

	/**
	 * Set a new password.
	 *
	 * @throws Auth.UserNotFound
	 * @throws Auth.WeakPassword
	 */
	function changePassword( required numeric userId, required string newPassword ){
		requireUser( arguments.userId );

		userRepository.updatePasswordHash(
			arguments.userId,
			passwordService.hashPassword( arguments.newPassword )
		);

		return this;
	}

	/**
	 * Confirm a password against a stored hash.
	 *
	 * This is the one piece of authentication Group 2 provides, and it stops
	 * here: no session, no cookie, no token. Establishing and carrying identity
	 * across requests belongs with routing and the API layer.
	 *
	 * An inactive user never verifies, regardless of the password.
	 */
	boolean function verifyPassword( required core.models.auth.User user, required string plainPassword ){
		if ( !arguments.user.isActive() ) {
			return false;
		}

		return passwordService.verify( arguments.plainPassword, arguments.user.getPasswordHash() );
	}

	function deactivateUser( required numeric userId ){
		var user = requireUser( arguments.userId );
		return userRepository.update( user.setStatus( "inactive" ) );
	}

	function activateUser( required numeric userId ){
		var user = requireUser( arguments.userId );
		return userRepository.update( user.setStatus( "active" ) );
	}

	function deleteUser( required numeric userId ){
		requireUser( arguments.userId );
		userRepository.delete( arguments.userId );
		return this;
	}

	/* ---------------------------------------------------------------------
	 * Role assignment
	 * ------------------------------------------------------------------ */

	/**
	 * Give a user one of their own site's roles.
	 *
	 * The database rejects a cross-tenant pairing through composite foreign
	 * keys; the checks here exist to produce a clear error rather than a
	 * constraint violation.
	 *
	 * @throws Auth.UserNotFound
	 * @throws Auth.RoleNotFound
	 * @throws Auth.SuperAdminRolesUnsupported
	 * @throws Auth.CrossTenantRoleAssignment
	 */
	function assignRole( required numeric userId, required numeric roleId ){
		var user = requireUser( arguments.userId );
		var role = roleRepository.findById( arguments.roleId );

		if ( isNull( role ) ) {
			throw( type = "Auth.RoleNotFound", message = "No role with id [#arguments.roleId#]." );
		}

		// A super admin already reaches everything; a role could only narrow
		// nothing, and they belong to no site for the join to hang off.
		if ( user.isSuperAdmin() ) {
			throw(
				type    = "Auth.SuperAdminRolesUnsupported",
				message = "A super admin holds every permission and cannot be assigned site roles."
			);
		}

		if ( role.getSiteId() != user.getSiteId() ) {
			throw(
				type    = "Auth.CrossTenantRoleAssignment",
				message = "Role [#arguments.roleId#] belongs to site [#role.getSiteId()#], but user [#arguments.userId#] belongs to site [#user.getSiteId()#]."
			);
		}

		roleRepository.assignRoleToUser( arguments.userId, arguments.roleId, user.getSiteId() );

		return this;
	}

	function removeRole( required numeric userId, required numeric roleId ){
		roleRepository.removeRoleFromUser( arguments.userId, arguments.roleId );
		return this;
	}

	array function getRoles( required numeric userId ){
		return roleRepository.findRolesForUser( arguments.userId );
	}

	/* ---------------------------------------------------------------------
	 * Reads
	 * ------------------------------------------------------------------ */

	function getUserById( required numeric userId ){
		return userRepository.findById( arguments.userId );
	}

	/**
	 * Find a user by their login identifier within a site.
	 */
	function getUserByEmailForSite( required string email, required numeric siteId ){
		return userRepository.findByEmailForSite( normalizeEmail( arguments.email ), arguments.siteId );
	}

	function getSuperAdminByEmail( required string email ){
		return userRepository.findSuperAdminByEmail( normalizeEmail( arguments.email ) );
	}

	array function getUsersForSite(
		required numeric siteId,
		numeric limit  = 25,
		numeric offset = 0
	){
		return userRepository.findBySiteId( arguments.siteId, arguments.limit, arguments.offset );
	}

	numeric function countUsersForSite( required numeric siteId ){
		return userRepository.countBySiteId( arguments.siteId );
	}

	array function getSuperAdmins(){
		return userRepository.findSuperAdmins();
	}

	/* ---------------------------------------------------------------------
	 * Helpers
	 * ------------------------------------------------------------------ */

	boolean function isValidStatus( required string status ){
		return [ "active", "inactive" ].findNoCase( arguments.status ) > 0;
	}

	/**
	 * Addresses are stored lower-cased and trimmed, so that lookups by email
	 * cannot miss on casing alone.
	 */
	string function normalizeEmail( required string email ){
		return lCase( trim( arguments.email ) );
	}

	boolean function isValidEmail( required string email ){
		return reFind( "^[^@\s]+@[^@\s.]+(\.[^@\s.]+)+$", arguments.email ) > 0;
	}

	private function requireUser( required numeric userId ){
		var user = userRepository.findById( arguments.userId );

		if ( isNull( user ) ) {
			throw( type = "Auth.UserNotFound", message = "No user with id [#arguments.userId#]." );
		}

		return user;
	}

	private function validateUserInput(
		required string name,
		required string email,
		required string status
	){
		if ( !len( trim( arguments.name ) ) ) {
			throw( type = "Auth.InvalidUser", message = "A user requires a name." );
		}

		if ( !isValidEmail( arguments.email ) ) {
			throw( type = "Auth.InvalidUser", message = "[#arguments.email#] is not a usable email address." );
		}

		if ( !isValidStatus( arguments.status ) ) {
			throw(
				type    = "Auth.InvalidUser",
				message = "Unknown user status [#arguments.status#]. Expected `active` or `inactive`."
			);
		}

		return this;
	}

}
