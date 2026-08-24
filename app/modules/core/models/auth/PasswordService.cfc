/**
 * Password hashing and verification.
 *
 * A thin seam over the BCrypt module. It exists so that the rest of the
 * application never touches a hashing library directly: the work factor is set
 * in one place, and moving to a different algorithm later means changing this
 * file rather than every caller.
 *
 * BCrypt is used rather than a hand-rolled scheme because salting, encoding and
 * constant-time comparison are exactly the details that go quietly wrong when
 * written by hand.
 */
component singleton accessors="true" {

	property name="bcrypt"   inject="BCrypt@bcrypt";
	property name="settings" inject="coldbox:moduleSettings:core";

	/**
	 * Minimum length enforced on new passwords.
	 *
	 * Deliberately a floor, not a composition rule: length is what actually
	 * resists guessing, and character-class requirements mostly push people
	 * towards predictable substitutions.
	 */
	variables.MIN_LENGTH = 12;

	numeric function getMinimumLength(){
		return variables.MIN_LENGTH;
	}

	/**
	 * Named `hashPassword`, not `hash`: ColdFusion has a built-in `hash()`, and
	 * a component method of that name is only safe while every call happens to
	 * be qualified. It works today and would break the first time something
	 * inside this component called it unqualified.
	 *
	 * @throws Auth.WeakPassword when the password is too short.
	 */
	string function hashPassword( required string plainPassword ){
		validate( arguments.plainPassword );

		return bcrypt.hashPassword( arguments.plainPassword, getWorkFactor() );
	}

	/**
	 * Verify a candidate password against a stored hash.
	 *
	 * Never throws on a mismatch — a wrong password is an expected outcome, not
	 * an exceptional one.
	 */
	boolean function verify( required string plainPassword, required string storedHash ){
		if ( !len( arguments.plainPassword ) || !len( arguments.storedHash ) ) {
			return false;
		}

		try {
			return bcrypt.checkPassword( arguments.plainPassword, arguments.storedHash );
		} catch ( any e ) {
			// A malformed or truncated hash must read as "does not match",
			// never as an error the caller might treat as success.
			return false;
		}
	}

	/**
	 * @throws Auth.WeakPassword
	 */
	function validate( required string plainPassword ){
		if ( len( arguments.plainPassword ) < variables.MIN_LENGTH ) {
			throw(
				type    = "Auth.WeakPassword",
				message = "A password must be at least #variables.MIN_LENGTH# characters."
			);
		}

		return this;
	}

	/**
	 * BCrypt cost. Higher is slower to hash and slower to attack.
	 */
	private numeric function getWorkFactor(){
		return val( settings.passwordWorkFactor ?: 12 );
	}

}
