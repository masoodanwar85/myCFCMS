/**
 * The authorisation rules, with the repository stubbed.
 *
 * The cases that matter most here are the denials — a permission check that
 * wrongly returns true is how one client ends up acting on another's site.
 */
component extends="coldbox.system.testing.BaseTestCase" appMapping="/app" {

	function beforeAll(){
		super.beforeAll();
	}

	function afterAll(){
		super.afterAll();
	}

	function run(){
		describe( "AuthorizationService", function(){

			beforeEach( function(){
				// A user on site 1 whose roles grant two permissions.
				variables.roleRepo = createStub()
					.$( "findPermissionSlugsForUser", [ "users.view", "users.create" ] )
					.$( "findRolesForUser", [] );

				variables.context = createStub()
					.$( "hasCurrentTenant", false )
					.$( "getCurrentTenantId", 0 );

				variables.auth = createMock( "core.models.auth.AuthorizationService" )
					.setRoleRepository( roleRepo )
					.setTenantContext( context );

				variables.user = makeUser( 1, 1 );
			} );

			describe( "granted permissions", function(){

				it( "allows a permission the user's roles grant", function(){
					expect( auth.can( user, "users.view", 1 ) ).toBeTrue();
					expect( auth.can( user, "users.create", 1 ) ).toBeTrue();
				} );

				it( "denies a permission no role grants", function(){
					expect( auth.can( user, "users.delete", 1 ) ).toBeFalse();
				} );

				it( "offers cannot() as the readable inverse", function(){
					expect( auth.cannot( user, "users.delete", 1 ) ).toBeTrue();
					expect( auth.cannot( user, "users.view", 1 ) ).toBeFalse();
				} );

			} );

			describe( "tenant boundaries", function(){

				it( "denies the very same permission on another site", function(){
					// The permission is held; the site is not theirs.
					expect( auth.can( user, "users.view", 1 ) ).toBeTrue();
					expect( auth.can( user, "users.view", 2 ) ).toBeFalse();
				} );

				it( "denies when no site is given and no tenant is resolved", function(){
					expect( auth.can( user, "users.view" ) ).toBeFalse();
				} );

				it( "falls back to the current request's tenant", function(){
					context.$( "hasCurrentTenant", true ).$( "getCurrentTenantId", 1 );

					expect( auth.can( user, "users.view" ) ).toBeTrue();
				} );

				it( "denies when the resolved tenant is a different site", function(){
					context.$( "hasCurrentTenant", true ).$( "getCurrentTenantId", 2 );

					expect( auth.can( user, "users.view" ) ).toBeFalse();
				} );

			} );

			describe( "super admins", function(){

				it( "allows any permission on any site", function(){
					var superAdmin = makeUser( 99 );

					expect( auth.can( superAdmin, "users.delete", 1 ) ).toBeTrue();
					expect( auth.can( superAdmin, "roles.delete", 2 ) ).toBeTrue();
					expect( auth.can( superAdmin, "anything.at.all", 12345 ) ).toBeTrue();
				} );

				it( "allows even with no site and no resolved tenant", function(){
					expect( auth.can( makeUser( 99 ), "users.delete" ) ).toBeTrue();
				} );

				it( "does not reach the roles tables at all", function(){
					auth.can( makeUser( 99 ), "users.delete", 1 );

					expect( roleRepo.$count( "findPermissionSlugsForUser" ) ).toBe( 0 );
				} );

				it( "is still denied once deactivated", function(){
					var superAdmin = makeUser( 99 ).setStatus( "inactive" );

					expect( auth.can( superAdmin, "users.view", 1 ) ).toBeFalse();
				} );

			} );

			describe( "inactive users", function(){

				it( "are denied permissions they would otherwise hold", function(){
					user.setStatus( "inactive" );

					expect( auth.can( user, "users.view", 1 ) ).toBeFalse();
				} );

			} );

			describe( "assertCan", function(){

				it( "passes silently when allowed", function(){
					expect( function(){
						auth.assertCan( user, "users.view", 1 );
					} ).notToThrow();
				} );

				it( "throws when denied", function(){
					expect( function(){
						auth.assertCan( user, "users.delete", 1 );
					} ).toThrow( type = "Auth.NotAuthorized" );
				} );

				it( "throws when the site is not the user's", function(){
					expect( function(){
						auth.assertCan( user, "users.view", 2 );
					} ).toThrow( type = "Auth.NotAuthorized" );
				} );

			} );

			describe( "canAll and canAny", function(){

				it( "canAll requires every permission", function(){
					expect( auth.canAll( user, [ "users.view", "users.create" ], 1 ) ).toBeTrue();
					expect( auth.canAll( user, [ "users.view", "users.delete" ], 1 ) ).toBeFalse();
				} );

				it( "canAny requires only one", function(){
					expect( auth.canAny( user, [ "users.delete", "users.view" ], 1 ) ).toBeTrue();
					expect( auth.canAny( user, [ "users.delete", "roles.delete" ], 1 ) ).toBeFalse();
				} );

				it( "both respect the tenant boundary", function(){
					expect( auth.canAll( user, [ "users.view" ], 2 ) ).toBeFalse();
					expect( auth.canAny( user, [ "users.view", "users.create" ], 2 ) ).toBeFalse();
				} );

			} );

			describe( "hasRole", function(){

				it( "is true for a role the user holds", function(){
					roleRepo.$( "findRolesForUser", [ makeRole( 1, 1, "owner" ) ] );

					expect( auth.hasRole( user, "owner" ) ).toBeTrue();
					expect( auth.hasRole( user, "editor" ) ).toBeFalse();
				} );

				it( "is false for a super admin, who holds no roles by design", function(){
					expect( auth.hasRole( makeUser( 99 ), "owner" ) ).toBeFalse();
				} );

			} );

		} );
	}

	/**
	 * @siteId Omit to build a platform super admin.
	 */
	private function makeUser( required numeric id, siteId ){
		var user = getInstance( "User@core" )
			.setId( arguments.id )
			.setName( "User #arguments.id#" )
			.setEmail( "user#arguments.id#@example.com" )
			.setPasswordHash( "irrelevant" );

		if ( !isNull( arguments.siteId ) ) {
			user.setSiteId( arguments.siteId );
		}

		return user;
	}

	private function makeRole( required numeric id, required numeric siteId, required string slug ){
		return getInstance( "Role@core" )
			.setId( arguments.id )
			.setSiteId( arguments.siteId )
			.setName( arguments.slug )
			.setSlug( arguments.slug );
	}

}
