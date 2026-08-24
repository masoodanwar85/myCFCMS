/**
 * CSRF tokens guard every state-changing admin request, so the properties that
 * make them worth having are pinned explicitly.
 */
component extends="coldbox.system.testing.BaseTestCase" appMapping="/app" {

	function beforeAll(){
		super.beforeAll();
		variables.csrf = getInstance( "CsrfService@core" );
	}

	function afterAll(){
		super.afterAll();
	}

	function run(){
		describe( "CsrfService", function(){

			beforeEach( function(){
				csrf.rotate();
			} );

			it( "issues a token", function(){
				var token = csrf.getCurrentToken();

				expect( len( token ) ).toBeGT( 30 );
			} );

			it( "returns the same token for the whole session", function(){
				expect( csrf.getCurrentToken() ).toBe( csrf.getCurrentToken() );
			} );

			it( "accepts its own token", function(){
				expect( csrf.verify( csrf.getCurrentToken() ) ).toBeTrue();
			} );

			it( "rejects anything else", function(){
				expect( csrf.verify( "not-the-token" ) ).toBeFalse();
				expect( csrf.verify( "" ) ).toBeFalse();
				expect( csrf.verify() ).toBeFalse();
			} );

			it( "rejects a token of the right length but wrong content", function(){
				var token = csrf.getCurrentToken();
				var forged = repeatString( "a", len( token ) );

				expect( csrf.verify( forged ) ).toBeFalse();
			} );

			it( "rejects a near miss", function(){
				var token = csrf.getCurrentToken();
				var almost = left( token, len( token ) - 1 ) & ( right( token, 1 ) == "a" ? "b" : "a" );

				expect( csrf.verify( almost ) ).toBeFalse();
			} );

			it( "issues a different token after rotating", function(){
				var before = csrf.getCurrentToken();

				csrf.rotate();

				expect( csrf.getCurrentToken() ).notToBe( before );
				expect( csrf.verify( before ) ).toBeFalse();
			} );

			it( "throws on an invalid token when asserting", function(){
				expect( function(){
					csrf.assertValid( "nope" );
				} ).toThrow( type = "Security.InvalidCsrfToken" );

				expect( function(){
					csrf.assertValid( csrf.getCurrentToken() );
				} ).notToThrow();
			} );

			it( "renders a hidden form field carrying the token", function(){
				var field = csrf.getFormField();

				expect( field ).toInclude( 'name="csrfToken"' );
				expect( field ).toInclude( csrf.getCurrentToken() );
			} );

		} );
	}

}
