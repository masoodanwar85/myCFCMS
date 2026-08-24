/**
 * Password hashing is the one place in Group 2 where a quiet mistake is a
 * security hole rather than a bug, so the properties are pinned explicitly.
 */
component extends="coldbox.system.testing.BaseTestCase" appMapping="/app" {

	function beforeAll(){
		super.beforeAll();
		variables.passwords = getInstance( "PasswordService@core" );
	}

	function afterAll(){
		super.afterAll();
	}

	function run(){
		describe( "PasswordService", function(){

			it( "produces a bcrypt hash", function(){
				var hash = passwords.hashPassword( "correct-horse-battery" );

				expect( hash ).toStartWith( "$2" );
				expect( len( hash ) ).toBe( 60 );
			} );

			it( "never returns the password itself", function(){
				var plain = "correct-horse-battery";

				expect( passwords.hashPassword( plain ) ).notToBe( plain );
				expect( passwords.hashPassword( plain ) ).notToInclude( plain );
			} );

			it( "salts, so the same password hashes differently every time", function(){
				var a = passwords.hashPassword( "correct-horse-battery" );
				var b = passwords.hashPassword( "correct-horse-battery" );

				expect( a ).notToBe( b );
			} );

			it( "verifies a correct password against either of those hashes", function(){
				var plain = "correct-horse-battery";

				expect( passwords.verify( plain, passwords.hashPassword( plain ) ) ).toBeTrue();
				expect( passwords.verify( plain, passwords.hashPassword( plain ) ) ).toBeTrue();
			} );

			it( "rejects a wrong password", function(){
				var hash = passwords.hashPassword( "correct-horse-battery" );

				expect( passwords.verify( "correct-horse-batterx", hash ) ).toBeFalse();
				expect( passwords.verify( "", hash ) ).toBeFalse();
			} );

			it( "is case sensitive", function(){
				var hash = passwords.hashPassword( "correct-horse-battery" );

				expect( passwords.verify( "CORRECT-HORSE-BATTERY", hash ) ).toBeFalse();
			} );

			it( "treats a malformed hash as a mismatch rather than an error", function(){
				expect( passwords.verify( "anything", "not-a-bcrypt-hash" ) ).toBeFalse();
				expect( passwords.verify( "anything", "" ) ).toBeFalse();
			} );

			it( "refuses a password shorter than the minimum", function(){
				expect( function(){
					passwords.hashPassword( repeatString( "a", passwords.getMinimumLength() - 1 ) );
				} ).toThrow( type = "Auth.WeakPassword" );
			} );

			it( "accepts a password at exactly the minimum", function(){
				var atLimit = repeatString( "a", passwords.getMinimumLength() );

				expect( passwords.verify( atLimit, passwords.hashPassword( atLimit ) ) ).toBeTrue();
			} );

		} );
	}

}
