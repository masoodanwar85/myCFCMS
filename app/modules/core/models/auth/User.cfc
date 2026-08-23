/**
 * A person who can sign in.
 *
 * Tenancy is carried by `siteId` alone: a user with no site is the platform
 * super admin, and every other user belongs to exactly one site. There is no
 * separate flag to fall out of step with it.
 *
 * State only — no persistence, no hashing, no request awareness.
 */
component accessors="true" {

	property name="id"           type="numeric";
	property name="siteId"       type="numeric";
	property name="name"         type="string";
	property name="email"        type="string";
	property name="passwordHash" type="string";
	property name="status"       type="string";
	property name="createdAt";
	property name="updatedAt";

	this.STATUS_ACTIVE   = "active";
	this.STATUS_INACTIVE = "inactive";

	function init(){
		variables.status = this.STATUS_ACTIVE;
		return this;
	}

	/**
	 * A user belonging to no site is the platform super admin, and reaches
	 * every tenant. See AuthorizationService.
	 */
	boolean function isSuperAdmin(){
		return isNull( variables.siteId );
	}

	boolean function isActive(){
		return variables.status == this.STATUS_ACTIVE;
	}

	/**
	 * Can this user act within the given site at all?
	 *
	 * Answers the tenancy question only. Whether they may perform a particular
	 * action there is AuthorizationService's business.
	 */
	boolean function belongsToSite( required numeric siteId ){
		if ( isSuperAdmin() ) {
			return true;
		}

		return variables.siteId == arguments.siteId;
	}

	/**
	 * Never includes the password hash. This is the struct that will feed API
	 * responses and views, and a hash has no business in either.
	 */
	struct function getMemento(){
		return {
			"id"           : variables.id,
			"siteId"       : isNull( variables.siteId ) ? "" : variables.siteId,
			"isSuperAdmin" : isSuperAdmin(),
			"name"         : variables.name,
			"email"        : variables.email,
			"status"       : variables.status,
			"createdAt"    : isNull( variables.createdAt ) ? "" : dateTimeFormat( variables.createdAt, "iso" ),
			"updatedAt"    : isNull( variables.updatedAt ) ? "" : dateTimeFormat( variables.updatedAt, "iso" )
		};
	}

}
