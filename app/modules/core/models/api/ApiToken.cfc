/**
 * One API credential.
 *
 * The plain token exists only on the instance returned by `issue()`, and is
 * never read back from the database — there is nothing there but a hash. Any
 * token loaded from storage has an empty `plainToken`, which is what makes
 * "show it once" a property of the design rather than a rule the admin screen
 * has to remember.
 */
component accessors="true" {

	property name="id"         type="numeric";
	property name="siteId"     type="numeric";
	property name="userId"     type="numeric";
	property name="name"       type="string";
	property name="tokenHash"  type="string";
	property name="prefix"     type="string";
	property name="lastUsedAt";
	property name="expiresAt";
	property name="revokedAt";
	property name="createdAt";
	property name="updatedAt";

	// Set once, at creation. Never persisted, never loaded.
	property name="plainToken" type="string";

	function init(){
		variables.plainToken = "";
		return this;
	}

	boolean function isRevoked(){
		return !isNull( variables.revokedAt );
	}

	boolean function isExpired(){
		return !isNull( variables.expiresAt ) && dateCompare( variables.expiresAt, now() ) < 0;
	}

	/**
	 * Usable right now?
	 *
	 * Expiry and revocation are separate states on purpose: "this was turned
	 * off" and "this ran out" are different things to show someone.
	 */
	boolean function isActive(){
		return !isRevoked() && !isExpired();
	}

	string function getStatus(){
		if ( isRevoked() ) {
			return "revoked";
		}
		if ( isExpired() ) {
			return "expired";
		}
		return "active";
	}

	/**
	 * What the admin can safely show: `mycms_ab12…`, never the token.
	 */
	string function getMasked(){
		return ( variables.prefix ?: "" ) & "…";
	}

}
