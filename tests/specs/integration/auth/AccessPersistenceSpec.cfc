/**
 * Group 2 against a real MySQL schema.
 *
 * The guarantees that matter most in a shared-database tenancy model are
 * enforced by indexes and composite foreign keys, not by CFML: email uniqueness
 * scoped per site, role slugs scoped per site, and — above all — the
 * impossibility of assigning one site's role to another site's user. Stubbing
 * those away would test nothing, so they are exercised here directly against
 * the repositories, bypassing the service pre-checks.
 *
 * Requires migrations to have run: `box migrate up`.
 *
 * Every row created here hangs off a `zzt-acc-` site and is removed afterwards.
 */
component extends="coldbox.system.testing.BaseTestCase" appMapping="/app" {

	variables.PREFIX   = "zzt-acc-";
	variables.PASSWORD = "correct-horse-battery";

	function beforeAll(){
		super.beforeAll();
		variables.sites    = getInstance( "SiteService@core" );
		variables.users    = getInstance( "UserService@core" );
		variables.roles    = getInstance( "RoleService@core" );
		variables.auth     = getInstance( "AuthorizationService@core" );
		variables.userRepo = getInstance( "UserRepository@core" );
		variables.roleRepo = getInstance( "RoleRepository@core" );
		variables.context  = getInstance( "TenantContext@core" );
		cleanup();
	}

	function afterAll(){
		cleanup();
		context.clear();
		super.afterAll();
	}

	function run(){
		describe( "Access persistence", function(){

			beforeEach( function(){
				context.clear();
			} );

			afterEach( function(){
				context.clear();
				cleanup();
			} );

			describe( "creating users", function(){

				it( "round-trips a site user", function(){
					var site = newSite( "One" );
					var user = users.createUser( site.getId(), "Ada", "ada@client.com", PASSWORD );

					expect( user.getId() ).toBeGT( 0 );

					var loaded = userRepo.findById( user.getId() );

					expect( loaded.getName() ).toBe( "Ada" );
					expect( loaded.getEmail() ).toBe( "ada@client.com" );
					expect( loaded.getSiteId() ).toBe( site.getId() );
					expect( loaded.isSuperAdmin() ).toBeFalse();
					expect( loaded.isActive() ).toBeTrue();
				} );

				it( "stores only a hash of the password", function(){
					var site   = newSite( "Two" );
					var user   = users.createUser( site.getId(), "Ada", "ada@client.com", PASSWORD );
					var loaded = userRepo.findById( user.getId() );

					expect( loaded.getPasswordHash() ).notToBe( PASSWORD );
					expect( loaded.getPasswordHash() ).toStartWith( "$2" );
					expect( users.verifyPassword( loaded, PASSWORD ) ).toBeTrue();
					expect( users.verifyPassword( loaded, "wrong-password-here" ) ).toBeFalse();
				} );

				it( "keeps the password hash out of the memento", function(){
					var site   = newSite( "Three" );
					var user   = users.createUser( site.getId(), "Ada", "ada@client.com", PASSWORD );
					var struct = user.getMemento();

					expect( struct ).notToHaveKey( "passwordHash" );
					expect( serializeJSON( struct ) ).notToInclude( "$2" );
				} );

				it( "refuses a duplicate email on the same site", function(){
					var site = newSite( "Four" );
					users.createUser( site.getId(), "Ada", "ada@client.com", PASSWORD );

					expect( function(){
						users.createUser( site.getId(), "Ada Two", "ada@client.com", PASSWORD );
					} ).toThrow( type = "Auth.EmailAlreadyTaken" );
				} );

				it( "enforces that in the database, not only in the service", function(){
					var site = newSite( "Five" );
					var user = users.createUser( site.getId(), "Ada", "ada@client.com", PASSWORD );

					// Straight at the repository, skipping the pre-check.
					expect( function(){
						userRepo.create(
							getInstance( "User@core" )
								.setSiteId( site.getId() )
								.setName( "Impostor" )
								.setEmail( "ada@client.com" )
								.setPasswordHash( "irrelevant" )
						);
					} ).toThrow( type = "Auth.EmailAlreadyTaken" );
				} );

				it( "allows the same email on two different sites", function(){
					var siteA = newSite( "Six A" );
					var siteB = newSite( "Six B" );

					var a = users.createUser( siteA.getId(), "Ada", "ada@shared.com", PASSWORD );
					var b = users.createUser( siteB.getId(), "Ada", "ada@shared.com", PASSWORD );

					expect( a.getId() ).notToBe( b.getId() );
					expect( a.getSiteId() ).notToBe( b.getSiteId() );
				} );

				it( "finds a user by email only within their own site", function(){
					var siteA = newSite( "Seven A" );
					var siteB = newSite( "Seven B" );
					var a     = users.createUser( siteA.getId(), "Ada", "ada@shared.com", PASSWORD );

					expect( users.getUserByEmailForSite( "ada@shared.com", siteA.getId() ).getId() ).toBe( a.getId() );
					expect( isNull( users.getUserByEmailForSite( "ada@shared.com", siteB.getId() ) ) ).toBeTrue();
				} );

			} );

			describe( "super admins", function(){

				it( "are stored with no site", function(){
					var admin  = newSuperAdmin( "root-one" );
					var loaded = userRepo.findById( admin.getId() );

					expect( loaded.isSuperAdmin() ).toBeTrue();
					expect( isNull( loaded.getSiteId() ) ).toBeTrue();
				} );

				it( "collide with each other on email despite the NULL site", function(){
					newSuperAdmin( "root-two" );

					expect( function(){
						users.createSuperAdmin( "Root Again", "#PREFIX#root-two@platform.com", PASSWORD );
					} ).toThrow( type = "Auth.EmailAlreadyTaken" );
				} );

				it( "do not collide with a site user at the same address", function(){
					var site = newSite( "Eight" );

					users.createSuperAdmin( "Root", "#PREFIX#root-three@platform.com", PASSWORD );

					expect( function(){
						users.createUser( site.getId(), "Also Root", "#PREFIX#root-three@platform.com", PASSWORD );
					} ).notToThrow();
				} );

				it( "are not returned when listing a site's users", function(){
					var site = newSite( "Nine" );
					newSuperAdmin( "root-four" );
					users.createUser( site.getId(), "Ada", "ada@client.com", PASSWORD );

					var siteUsers = users.getUsersForSite( site.getId() );

					expect( siteUsers.len() ).toBe( 1 );
					expect( siteUsers[ 1 ].getName() ).toBe( "Ada" );
				} );

			} );

			describe( "seeding default roles", function(){

				it( "gives a new site an owner and an editor", function(){
					var site  = newSite( "Ten" );
					var seeded = roles.seedDefaultRolesForSite( site.getId() );

					var slugs = seeded.map( ( r ) => r.getSlug() );
					expect( slugs ).toInclude( "owner" );
					expect( slugs ).toInclude( "editor" );
				} );

				it( "grants the owner every core permission", function(){
					var site = newSite( "Eleven" );
					roles.seedDefaultRolesForSite( site.getId() );

					var owner   = roles.getRoleBySlugForSite( "owner", site.getId() );
					var granted = roles.getPermissions( owner.getId() );

					expect( granted ).toInclude( "users.delete" );
					expect( granted ).toInclude( "roles.delete" );
					expect( granted ).toInclude( "site.settings.manage" );
					expect( granted.len() ).toBe( roles.getAllPermissions().len() );
				} );

				it( "gives the editor a strictly smaller set", function(){
					var site = newSite( "Twelve" );
					roles.seedDefaultRolesForSite( site.getId() );

					var editor = roles.getPermissions( roles.getRoleBySlugForSite( "editor", site.getId() ).getId() );

					expect( editor ).toInclude( "site.view" );
					expect( editor ).notToInclude( "users.delete" );
					expect( editor ).notToInclude( "site.update" );
				} );

				it( "is idempotent", function(){
					var site = newSite( "Thirteen" );

					roles.seedDefaultRolesForSite( site.getId() );
					var second = roles.seedDefaultRolesForSite( site.getId() );

					expect( second.len() ).toBe( 2 );
				} );

			} );

			describe( "per-site custom roles", function(){

				it( "creates a role owned by the site", function(){
					var site = newSite( "Fourteen" );
					var role = roles.createRole( site.getId(), "Content Reviewer" );

					expect( role.getSiteId() ).toBe( site.getId() );
					expect( role.getSlug() ).toBe( "content-reviewer" );
				} );

				it( "refuses a duplicate slug on the same site", function(){
					var site = newSite( "Fifteen" );
					roles.createRole( site.getId(), "Reviewer" );

					expect( function(){
						roles.createRole( site.getId(), "Reviewer" );
					} ).toThrow( type = "Auth.RoleSlugAlreadyTaken" );
				} );

				it( "allows the same slug on a different site", function(){
					var siteA = newSite( "Sixteen A" );
					var siteB = newSite( "Sixteen B" );

					var a = roles.createRole( siteA.getId(), "Reviewer" );
					var b = roles.createRole( siteB.getId(), "Reviewer" );

					expect( a.getSlug() ).toBe( b.getSlug() );
					expect( a.getId() ).notToBe( b.getId() );
				} );

				it( "only lists roles of the site asked for", function(){
					var siteA = newSite( "Seventeen A" );
					var siteB = newSite( "Seventeen B" );

					roles.createRole( siteA.getId(), "Only Mine" );

					expect( roles.getRolesForSite( siteB.getId() ).len() ).toBe( 0 );
					expect( roles.getRolesForSite( siteA.getId() ).len() ).toBe( 1 );
				} );

			} );

			describe( "granting permissions to a role", function(){

				it( "grants and reads back", function(){
					var site = newSite( "Eighteen" );
					var role = roles.createRole( site.getId(), "Reviewer" );

					roles.grantPermission( role.getId(), "users.view" );

					expect( roles.getPermissions( role.getId() ) ).toInclude( "users.view" );
				} );

				it( "is idempotent", function(){
					var site = newSite( "Nineteen" );
					var role = roles.createRole( site.getId(), "Reviewer" );

					roles.grantPermission( role.getId(), "users.view" );
					roles.grantPermission( role.getId(), "users.view" );

					expect( roles.getPermissions( role.getId() ).len() ).toBe( 1 );
				} );

				it( "revokes", function(){
					var site = newSite( "Twenty" );
					var role = roles.createRole( site.getId(), "Reviewer" );

					roles.grantPermissions( role.getId(), [ "users.view", "users.create" ] );
					roles.revokePermission( role.getId(), "users.create" );

					var granted = roles.getPermissions( role.getId() );
					expect( granted ).toInclude( "users.view" );
					expect( granted ).notToInclude( "users.create" );
				} );

				it( "refuses a permission that is not in the catalogue", function(){
					var site = newSite( "Twentyone" );
					var role = roles.createRole( site.getId(), "Reviewer" );

					expect( function(){
						roles.grantPermission( role.getId(), "not.a.real.permission" );
					} ).toThrow( type = "Auth.PermissionNotFound" );
				} );

				it( "rejects a whole batch containing an unknown slug", function(){
					var site = newSite( "Twentytwo" );
					var role = roles.createRole( site.getId(), "Reviewer" );

					expect( function(){
						roles.grantPermissions( role.getId(), [ "users.view", "not.real" ] );
					} ).toThrow( type = "Auth.PermissionNotFound" );

					// Nothing partially applied.
					expect( roles.getPermissions( role.getId() ).len() ).toBe( 0 );
				} );

				it( "leaves a role untouched when a sync set is invalid", function(){
					var site = newSite( "Twentythree" );
					var role = roles.createRole( site.getId(), "Reviewer" );
					roles.grantPermission( role.getId(), "users.view" );

					expect( function(){
						roles.syncPermissions( role.getId(), [ "users.create", "not.real" ] );
					} ).toThrow( type = "Auth.PermissionNotFound" );

					expect( roles.getPermissions( role.getId() ) ).toInclude( "users.view" );
				} );

				it( "replaces the set on a valid sync", function(){
					var site = newSite( "Twentyfour" );
					var role = roles.createRole( site.getId(), "Reviewer" );
					roles.grantPermission( role.getId(), "users.view" );

					roles.syncPermissions( role.getId(), [ "roles.view" ] );

					var granted = roles.getPermissions( role.getId() );
					expect( granted ).toBe( [ "roles.view" ] );
				} );

			} );

			describe( "assigning roles to users", function(){

				it( "assigns a role from the user's own site", function(){
					var site = newSite( "Twentyfive" );
					var user = users.createUser( site.getId(), "Ada", "ada@client.com", PASSWORD );
					var role = roles.createRole( site.getId(), "Reviewer" );

					users.assignRole( user.getId(), role.getId() );

					expect( users.getRoles( user.getId() ).len() ).toBe( 1 );
					expect( users.getRoles( user.getId() )[ 1 ].getSlug() ).toBe( "reviewer" );
				} );

				it( "is idempotent", function(){
					var site = newSite( "Twentysix" );
					var user = users.createUser( site.getId(), "Ada", "ada@client.com", PASSWORD );
					var role = roles.createRole( site.getId(), "Reviewer" );

					users.assignRole( user.getId(), role.getId() );
					users.assignRole( user.getId(), role.getId() );

					expect( users.getRoles( user.getId() ).len() ).toBe( 1 );
				} );

				it( "accumulates permissions across several roles", function(){
					var site  = newSite( "Twentyseven" );
					var user  = users.createUser( site.getId(), "Ada", "ada@client.com", PASSWORD );
					var one   = roles.createRole( site.getId(), "Role One" );
					var two   = roles.createRole( site.getId(), "Role Two" );

					roles.grantPermission( one.getId(), "users.view" );
					roles.grantPermission( two.getId(), "roles.view" );
					users.assignRole( user.getId(), one.getId() );
					users.assignRole( user.getId(), two.getId() );

					var held = auth.getPermissionsFor( userRepo.findById( user.getId() ) );

					expect( held ).toInclude( "users.view" );
					expect( held ).toInclude( "roles.view" );
				} );

				it( "does not duplicate a permission granted by two roles", function(){
					var site = newSite( "Twentyeight" );
					var user = users.createUser( site.getId(), "Ada", "ada@client.com", PASSWORD );
					var one  = roles.createRole( site.getId(), "Role One" );
					var two  = roles.createRole( site.getId(), "Role Two" );

					roles.grantPermission( one.getId(), "users.view" );
					roles.grantPermission( two.getId(), "users.view" );
					users.assignRole( user.getId(), one.getId() );
					users.assignRole( user.getId(), two.getId() );

					expect( auth.getPermissionsFor( userRepo.findById( user.getId() ) ).len() ).toBe( 1 );
				} );

				it( "removes a role and the permissions it carried", function(){
					var site = newSite( "Twentynine" );
					var user = users.createUser( site.getId(), "Ada", "ada@client.com", PASSWORD );
					var role = roles.createRole( site.getId(), "Reviewer" );

					roles.grantPermission( role.getId(), "users.view" );
					users.assignRole( user.getId(), role.getId() );
					users.removeRole( user.getId(), role.getId() );

					expect( auth.getPermissionsFor( userRepo.findById( user.getId() ) ).len() ).toBe( 0 );
				} );

			} );

			describe( "cross-tenant role assignment", function(){

				it( "is refused by the service", function(){
					var siteA = newSite( "Thirty A" );
					var siteB = newSite( "Thirty B" );
					var user  = users.createUser( siteA.getId(), "Ada", "ada@client.com", PASSWORD );
					var role  = roles.createRole( siteB.getId(), "Reviewer" );

					expect( function(){
						users.assignRole( user.getId(), role.getId() );
					} ).toThrow( type = "Auth.CrossTenantRoleAssignment" );
				} );

				it( "is refused by the database even when the service is bypassed", function(){
					var siteA = newSite( "Thirtyone A" );
					var siteB = newSite( "Thirtyone B" );
					var user  = users.createUser( siteA.getId(), "Ada", "ada@client.com", PASSWORD );
					var role  = roles.createRole( siteB.getId(), "Reviewer" );

					// Straight at the repository, with either site id: the composite
					// foreign keys require the user AND the role to match the row's site.
					expect( function(){
						roleRepo.assignRoleToUser( user.getId(), role.getId(), siteA.getId() );
					} ).toThrow( type = "Auth.CrossTenantRoleAssignment" );

					expect( function(){
						roleRepo.assignRoleToUser( user.getId(), role.getId(), siteB.getId() );
					} ).toThrow( type = "Auth.CrossTenantRoleAssignment" );

					expect( users.getRoles( user.getId() ).len() ).toBe( 0 );
				} );

			} );

			describe( "authorisation end to end", function(){

				it( "allows what the user's roles grant and denies the rest", function(){
					var site = newSite( "Thirtytwo" );
					roles.seedDefaultRolesForSite( site.getId() );

					var user = users.createUser( site.getId(), "Ed", "ed@client.com", PASSWORD );
					users.assignRole( user.getId(), roles.getRoleBySlugForSite( "editor", site.getId() ).getId() );

					var loaded = userRepo.findById( user.getId() );

					expect( auth.can( loaded, "site.view", site.getId() ) ).toBeTrue();
					expect( auth.can( loaded, "users.delete", site.getId() ) ).toBeFalse();
				} );

				it( "denies the same permission on another site", function(){
					var siteA = newSite( "Thirtythree A" );
					var siteB = newSite( "Thirtythree B" );
					roles.seedDefaultRolesForSite( siteA.getId() );

					var user = users.createUser( siteA.getId(), "Owner", "owner@client.com", PASSWORD );
					users.assignRole( user.getId(), roles.getRoleBySlugForSite( "owner", siteA.getId() ).getId() );

					var loaded = userRepo.findById( user.getId() );

					expect( auth.can( loaded, "users.delete", siteA.getId() ) ).toBeTrue();
					expect( auth.can( loaded, "users.delete", siteB.getId() ) ).toBeFalse();
				} );

				it( "lets a super admin act on any site", function(){
					var site  = newSite( "Thirtyfour" );
					var admin = newSuperAdmin( "root-five" );

					expect( auth.can( admin, "users.delete", site.getId() ) ).toBeTrue();
					expect( auth.can( admin, "roles.delete", site.getId() ) ).toBeTrue();
				} );

				it( "uses the tenant resolved for the request when no site is given", function(){
					var site = newSite( "Thirtyfive" );
					roles.seedDefaultRolesForSite( site.getId() );

					var user = users.createUser( site.getId(), "Ed", "ed@client.com", PASSWORD );
					users.assignRole( user.getId(), roles.getRoleBySlugForSite( "editor", site.getId() ).getId() );

					var loaded = userRepo.findById( user.getId() );

					context.setCurrentTenant( site );

					expect( auth.can( loaded, "site.view" ) ).toBeTrue();
					expect( auth.can( loaded, "users.delete" ) ).toBeFalse();
				} );

				it( "denies once the user is deactivated", function(){
					var site = newSite( "Thirtysix" );
					roles.seedDefaultRolesForSite( site.getId() );

					var user = users.createUser( site.getId(), "Ed", "ed@client.com", PASSWORD );
					users.assignRole( user.getId(), roles.getRoleBySlugForSite( "owner", site.getId() ).getId() );
					users.deactivateUser( user.getId() );

					var loaded = userRepo.findById( user.getId() );

					expect( auth.can( loaded, "site.view", site.getId() ) ).toBeFalse();
				} );

			} );

			describe( "cascade deletes", function(){

				it( "removes a site's users, roles and assignments with the site", function(){
					var site = newSite( "Thirtyseven" );
					roles.seedDefaultRolesForSite( site.getId() );

					var user = users.createUser( site.getId(), "Ada", "ada@client.com", PASSWORD );
					users.assignRole( user.getId(), roles.getRoleBySlugForSite( "owner", site.getId() ).getId() );

					queryExecute( "DELETE FROM sites WHERE id = :id", { id : site.getId() } );

					expect( isNull( userRepo.findById( user.getId() ) ) ).toBeTrue();
					expect( roles.getRolesForSite( site.getId() ).len() ).toBe( 0 );
					expect( users.getRoles( user.getId() ).len() ).toBe( 0 );
				} );

				it( "removes a user's role assignments when the user goes", function(){
					var site = newSite( "Thirtyeight" );
					var user = users.createUser( site.getId(), "Ada", "ada@client.com", PASSWORD );
					var role = roles.createRole( site.getId(), "Reviewer" );

					users.assignRole( user.getId(), role.getId() );
					users.deleteUser( user.getId() );

					expect( users.getRoles( user.getId() ).len() ).toBe( 0 );
					// The role itself survives.
					expect( isNull( roles.getRoleById( role.getId() ) ) ).toBeFalse();
				} );

				it( "removes assignments and grants when a role goes", function(){
					var site = newSite( "Thirtynine" );
					var user = users.createUser( site.getId(), "Ada", "ada@client.com", PASSWORD );
					var role = roles.createRole( site.getId(), "Reviewer" );

					roles.grantPermission( role.getId(), "users.view" );
					users.assignRole( user.getId(), role.getId() );
					roles.deleteRole( role.getId() );

					expect( users.getRoles( user.getId() ).len() ).toBe( 0 );
					// The user and the catalogue survive.
					expect( isNull( userRepo.findById( user.getId() ) ) ).toBeFalse();
					expect( roles.getAllPermissions().len() ).toBeGT( 0 );
				} );

			} );

		} );
	}

	private function newSite( required string name ){
		return sites.createSite(
			name = arguments.name,
			slug = PREFIX & sites.slugify( arguments.name ) & "-" & createUUID().left( 8 )
		);
	}

	private function newSuperAdmin( required string handle ){
		return users.createSuperAdmin(
			name     = "Root #arguments.handle#",
			email    = "#PREFIX##arguments.handle#@platform.com",
			password = PASSWORD
		);
	}

	/**
	 * Site-owned rows go with their site through ON DELETE CASCADE.
	 * Super admins belong to no site, so they are removed by address.
	 */
	private function cleanup(){
		queryExecute( "DELETE FROM sites WHERE slug LIKE :prefix", { prefix : PREFIX & "%" } );
		queryExecute(
			"DELETE FROM users WHERE site_id IS NULL AND email LIKE :prefix",
			{ prefix : PREFIX & "%" }
		);
	}

}
