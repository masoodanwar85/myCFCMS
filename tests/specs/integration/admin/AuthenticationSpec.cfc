/**
 * Signing in, against real users in a real database.
 *
 * The cases that matter are the refusals, and above all the tenant ones: a
 * session must not survive being carried to another site.
 *
 * Requires migrations to have run: `box migrate up`.
 */
component extends="coldbox.system.testing.BaseTestCase" appMapping="/app" {

	variables.PREFIX   = "zzt-au-";
	variables.PASSWORD = "correct-horse-battery";

	function beforeAll(){
		super.beforeAll();
		variables.sites   = getInstance( "SiteService@core" );
		variables.users   = getInstance( "UserService@core" );
		variables.auth    = getInstance( "AuthenticationService@core" );
		variables.context = getInstance( "TenantContext@core" );
		cleanup();

		variables.siteOne = sites.createSite( name = "Auth One", slug = PREFIX & "one" );
		variables.siteTwo = sites.createSite( name = "Auth Two", slug = PREFIX & "two" );

		variables.ada = users.createUser( siteOne.getId(), "Ada", "ada@auth.test", PASSWORD );
		variables.eve = users.createUser( siteTwo.getId(), "Eve", "eve@auth.test", PASSWORD );
		variables.root = users.createSuperAdmin( "Root", "#PREFIX#root@platform.test", PASSWORD );
	}

	function afterAll(){
		auth.logout();
		context.clear();
		cleanup();
		super.afterAll();
	}

	function run(){
		describe( "AuthenticationService", function(){

			beforeEach( function(){
				auth.logout();
				context.clear();
			} );

			afterEach( function(){
				auth.logout();
				context.clear();
			} );

			describe( "signing in", function(){

				it( "accepts a site user's own credentials", function(){
					context.setCurrentTenant( siteOne );

					var user = auth.login( "ada@auth.test", PASSWORD );

					expect( user.getId() ).toBe( ada.getId() );
					expect( auth.isLoggedIn() ).toBeTrue();
				} );

				it( "accepts a super admin on any site", function(){
					context.setCurrentTenant( siteTwo );

					expect( auth.login( "#PREFIX#root@platform.test", PASSWORD ).getId() ).toBe( root.getId() );
				} );

				it( "refuses a wrong password", function(){
					context.setCurrentTenant( siteOne );

					expect( function(){
						auth.login( "ada@auth.test", "wrong-password-entirely" );
					} ).toThrow( type = "Auth.InvalidCredentials" );

					expect( auth.isLoggedIn() ).toBeFalse();
				} );

				it( "refuses an unknown email with the same error as a wrong password", function(){
					context.setCurrentTenant( siteOne );

					// Distinguishing the two would reveal who has an account.
					expect( function(){
						auth.login( "nobody@auth.test", PASSWORD );
					} ).toThrow( type = "Auth.InvalidCredentials" );
				} );

				it( "refuses a user of another site", function(){
					context.setCurrentTenant( siteOne );

					expect( function(){
						auth.login( "eve@auth.test", PASSWORD );
					} ).toThrow( type = "Auth.InvalidCredentials" );
				} );

				it( "refuses a deactivated user", function(){
					users.deactivateUser( ada.getId() );
					context.setCurrentTenant( siteOne );

					try {
						expect( function(){
							auth.login( "ada@auth.test", PASSWORD );
						} ).toThrow( type = "Auth.InvalidCredentials" );
					} finally {
						users.activateUser( ada.getId() );
					}
				} );

				it( "refuses when the host resolves to no site", function(){
					expect( function(){
						auth.login( "ada@auth.test", PASSWORD );
					} ).toThrow( type = "Auth.NoTenant" );
				} );

				it( "is not case sensitive about the email", function(){
					context.setCurrentTenant( siteOne );

					expect( auth.login( "  ADA@Auth.TEST  ", PASSWORD ).getId() ).toBe( ada.getId() );
				} );

			} );

			describe( "the current user", function(){

				it( "is null before signing in", function(){
					context.setCurrentTenant( siteOne );

					expect( isNull( auth.getCurrentUser() ) ).toBeTrue();
				} );

				it( "is the signed-in user afterwards", function(){
					context.setCurrentTenant( siteOne );
					auth.login( "ada@auth.test", PASSWORD );

					expect( auth.getCurrentUser().getId() ).toBe( ada.getId() );
				} );

				it( "does not carry to another tenant", function(){
					context.setCurrentTenant( siteOne );
					auth.login( "ada@auth.test", PASSWORD );

					// Same session, different site: the identity must not follow.
					context.clear();
					context.setCurrentTenant( siteTwo );

					expect( isNull( auth.getCurrentUser() ) ).toBeTrue();
				} );

				it( "stops being valid once the account is deactivated", function(){
					context.setCurrentTenant( siteOne );
					auth.login( "ada@auth.test", PASSWORD );

					users.deactivateUser( ada.getId() );
					structDelete( request, "cms_authCurrentUser" );

					try {
						expect( isNull( auth.getCurrentUser() ) ).toBeTrue();
					} finally {
						users.activateUser( ada.getId() );
					}
				} );

				it( "is null with no tenant at all", function(){
					context.setCurrentTenant( siteOne );
					auth.login( "ada@auth.test", PASSWORD );

					context.clear();
					structDelete( request, "cms_authCurrentUser" );

					expect( isNull( auth.getCurrentUser() ) ).toBeTrue();
				} );

			} );

			describe( "signing out", function(){

				it( "ends the session", function(){
					context.setCurrentTenant( siteOne );
					auth.login( "ada@auth.test", PASSWORD );

					auth.logout();

					expect( auth.isLoggedIn() ).toBeFalse();
					expect( isNull( auth.getCurrentUser() ) ).toBeTrue();
				} );

			} );

		} );
	}

	private function cleanup(){
		queryExecute( "DELETE FROM sites WHERE slug LIKE :p", { p : PREFIX & "%" } );
		queryExecute( "DELETE FROM users WHERE site_id IS NULL AND email LIKE :p", { p : PREFIX & "%" } );
	}

}
