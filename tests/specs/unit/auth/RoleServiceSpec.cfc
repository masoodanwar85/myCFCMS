/**
 * RoleService's validation and slug derivation, with repositories stubbed.
 * Persistence-level rules (per-site slug uniqueness, grant idempotency) are
 * covered by the integration specs.
 */
component extends="coldbox.system.testing.BaseTestCase" appMapping="/app" {

	function beforeAll(){
		super.beforeAll();
	}

	function afterAll(){
		super.afterAll();
	}

	function run(){
		describe( "RoleService", function(){

			beforeEach( function(){
				variables.roleRepo = createStub()
					.$( "existsBySlugForSite", false )
					.$( "create" )
					.$( "update" )
					.$( "grantPermission" )
					.$( "revokeAllPermissions" )
					.$( "findBySlugForSite" )
					.$( "findBySiteId", [] );

				variables.permissionRepo = createStub().$( "findIdsBySlugs", {} );
				variables.siteRepo       = createStub().$( "findById", makeSite( 1 ) );

				variables.service = createMock( "core.models.auth.RoleService" )
					.setRoleRepository( roleRepo )
					.setPermissionRepository( permissionRepo )
					.setSiteRepository( siteRepo )
					.setWirebox( getWireBox() );
			} );

			describe( "creating a role", function(){

				it( "derives a slug from the name", function(){
					roleRepo.$( "create", makeRole( 1, 1, "content-reviewer" ) );

					service.createRole( 1, "Content Reviewer" );

					expect( roleRepo.$callLog().create[ 1 ][ 1 ].getSlug() ).toBe( "content-reviewer" );
				} );

				it( "normalises an explicit slug", function(){
					roleRepo.$( "create", makeRole( 1, 1, "content-reviewer" ) );

					service.createRole( 1, "Whatever", "  Content REVIEWER  " );

					expect( roleRepo.$callLog().create[ 1 ][ 1 ].getSlug() ).toBe( "content-reviewer" );
				} );

				it( "owns the role to the given site", function(){
					roleRepo.$( "create", makeRole( 1, 1, "reviewer" ) );

					service.createRole( 1, "Reviewer" );

					expect( roleRepo.$callLog().create[ 1 ][ 1 ].getSiteId() ).toBe( 1 );
				} );

				it( "rejects an empty name", function(){
					expect( function(){
						service.createRole( 1, "   " );
					} ).toThrow( type = "Auth.InvalidRole" );
				} );

				it( "rejects a name that yields no usable slug", function(){
					expect( function(){
						service.createRole( 1, "!!!" );
					} ).toThrow( type = "Auth.InvalidRole" );
				} );

				it( "rejects an unknown site", function(){
					siteRepo.$( "findById" );

					expect( function(){
						service.createRole( 999, "Reviewer" );
					} ).toThrow( type = "Auth.SiteNotFound" );
				} );

				it( "refuses a slug the site already uses", function(){
					roleRepo.$( "existsBySlugForSite", true );

					expect( function(){
						service.createRole( 1, "Reviewer" );
					} ).toThrow( type = "Auth.RoleSlugAlreadyTaken" );
				} );

				it( "scopes the uniqueness check to the site", function(){
					roleRepo.$( "create", makeRole( 1, 1, "reviewer" ) );

					service.createRole( 1, "Reviewer" );

					var call = roleRepo.$callLog().existsBySlugForSite[ 1 ];
					expect( call[ 1 ] ).toBe( "reviewer" );
					expect( call[ 2 ] ).toBe( 1 );
				} );

			} );

			describe( "granting permissions", function(){

				beforeEach( function(){
					roleRepo.$( "findById", makeRole( 5, 1, "reviewer" ) );
				} );

				it( "resolves every slug in one lookup", function(){
					permissionRepo.$( "findIdsBySlugs", { "users.view" : 1, "roles.view" : 2 } );

					service.grantPermissions( 5, [ "users.view", "roles.view" ] );

					expect( permissionRepo.$count( "findIdsBySlugs" ) ).toBe( 1 );
					expect( roleRepo.$count( "grantPermission" ) ).toBe( 2 );
				} );

				it( "refuses the whole batch if any slug is unknown", function(){
					permissionRepo.$( "findIdsBySlugs", { "users.view" : 1 } );

					expect( function(){
						service.grantPermissions( 5, [ "users.view", "not.real" ] );
					} ).toThrow( type = "Auth.PermissionNotFound" );

					expect( roleRepo.$count( "grantPermission" ) ).toBe( 0 );
				} );

				it( "validates a sync set before clearing the old one", function(){
					permissionRepo.$( "findIdsBySlugs", { "users.view" : 1 } );

					expect( function(){
						service.syncPermissions( 5, [ "users.view", "not.real" ] );
					} ).toThrow( type = "Auth.PermissionNotFound" );

					expect( roleRepo.$count( "revokeAllPermissions" ) ).toBe( 0 );
				} );

				it( "rejects an unknown role", function(){
					roleRepo.$( "findById" );

					expect( function(){
						service.grantPermissions( 999, [ "users.view" ] );
					} ).toThrow( type = "Auth.RoleNotFound" );
				} );

			} );

			describe( "default role definitions", function(){

				it( "resolve the owner from the catalogue rather than a fixed list", function(){
					var owner = service.getDefaultRoleDefinitions().filter( ( d ) => d.slug == "owner" )[ 1 ];

					// A hard-coded list would stop being complete the moment a
					// module registers new permissions.
					expect( owner.grantsEverything ?: false ).toBeTrue();
				} );

				it( "grant the owner every registered permission when seeding", function(){
					permissionRepo.$( "findAll", [ makePermission( "a.one" ), makePermission( "b.two" ) ] );
					// Seeding grants the editor role too, so the stub has to
					// resolve its slugs as well as the owner's.
					permissionRepo.$(
						"findIdsBySlugs",
						{
							"a.one"      : 1,
							"b.two"      : 2,
							"site.view"  : 3,
							"users.view" : 4,
							"roles.view" : 5
						}
					);
					roleRepo.$( "findBySlugForSite", makeRole( 5, 1, "owner" ) );
					roleRepo.$( "findById", makeRole( 5, 1, "owner" ) );

					service.seedDefaultRolesForSite( 1 );

					// Owner is seeded first, so the first call is its slug set.
					var requested = permissionRepo.$callLog().findIdsBySlugs[ 1 ][ 1 ];
					expect( requested ).toInclude( "a.one" );
					expect( requested ).toInclude( "b.two" );
					expect( requested.len() ).toBe( 2 );
				} );

				it( "keep configuration and access control away from the editor", function(){
					var editor = service.getDefaultRoleDefinitions().filter( ( d ) => d.slug == "editor" )[ 1 ];

					expect( editor.permissions ).notToInclude( "site.update" );
					expect( editor.permissions ).notToInclude( "users.create" );
					expect( editor.permissions ).notToInclude( "roles.update" );
				} );

			} );

		} );
	}

	private function makeSite( required numeric id ){
		return getInstance( "Site@core" ).setId( arguments.id ).setName( "Site" ).setSlug( "site-#arguments.id#" );
	}

	private function makePermission( required string slug ){
		return getInstance( "Permission@core" ).setSlug( arguments.slug ).setName( arguments.slug );
	}

	private function makeRole( required numeric id, required numeric siteId, required string slug ){
		return getInstance( "Role@core" )
			.setId( arguments.id )
			.setSiteId( arguments.siteId )
			.setName( arguments.slug )
			.setSlug( arguments.slug );
	}

}
