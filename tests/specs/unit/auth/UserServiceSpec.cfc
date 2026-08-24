/**
 * UserService's own validation and orchestration, with repositories stubbed.
 * The database constraints backing the same rules are covered by the
 * integration specs.
 */
component extends="coldbox.system.testing.BaseTestCase" appMapping="/app" {

	function beforeAll(){
		super.beforeAll();
	}

	function afterAll(){
		super.afterAll();
	}

	function run(){
		describe( "UserService", function(){

			beforeEach( function(){
				variables.userRepo = createStub()
					.$( "existsByEmailInScope", false )
					.$( "create" )
					.$( "update" )
					.$( "updatePasswordHash" );

				variables.roleRepo = createStub()
					.$( "assignRoleToUser" )
					.$( "removeRoleFromUser" );

				variables.siteRepo = createStub().$( "findById", makeSite( 1 ) );

				variables.service = createMock( "core.models.auth.UserService" )
					.setUserRepository( userRepo )
					.setRoleRepository( roleRepo )
					.setSiteRepository( siteRepo )
					.setPasswordService( getInstance( "PasswordService@core" ) )
					.setWirebox( getWireBox() );
			} );

			describe( "creating a site user", function(){

				it( "stores a hash, never the password", function(){
					userRepo.$( "create", makeUser( 1, 1 ) );

					service.createUser( 1, "Ada", "ada@client.com", "correct-horse-battery" );

					var persisted = userRepo.$callLog().create[ 1 ][ 1 ];
					expect( persisted.getPasswordHash() ).notToBe( "correct-horse-battery" );
					expect( persisted.getPasswordHash() ).toStartWith( "$2" );
				} );

				it( "attaches the user to the given site", function(){
					userRepo.$( "create", makeUser( 1, 1 ) );

					service.createUser( 1, "Ada", "ada@client.com", "correct-horse-battery" );

					var persisted = userRepo.$callLog().create[ 1 ][ 1 ];
					expect( persisted.getSiteId() ).toBe( 1 );
					expect( persisted.isSuperAdmin() ).toBeFalse();
				} );

				it( "lower-cases and trims the email", function(){
					userRepo.$( "create", makeUser( 1, 1 ) );

					service.createUser( 1, "Ada", "  Ada@Client.COM  ", "correct-horse-battery" );

					expect( userRepo.$callLog().create[ 1 ][ 1 ].getEmail() ).toBe( "ada@client.com" );
				} );

				it( "rejects a malformed email", function(){
					expect( function(){
						service.createUser( 1, "Ada", "not-an-email", "correct-horse-battery" );
					} ).toThrow( type = "Auth.InvalidUser" );
				} );

				it( "rejects an empty name", function(){
					expect( function(){
						service.createUser( 1, "   ", "ada@client.com", "correct-horse-battery" );
					} ).toThrow( type = "Auth.InvalidUser" );
				} );

				it( "rejects a weak password before touching the database", function(){
					expect( function(){
						service.createUser( 1, "Ada", "ada@client.com", "short" );
					} ).toThrow( type = "Auth.WeakPassword" );

					expect( userRepo.$count( "create" ) ).toBe( 0 );
				} );

				it( "rejects an unknown site", function(){
					siteRepo.$( "findById" );

					expect( function(){
						service.createUser( 999, "Ada", "ada@client.com", "correct-horse-battery" );
					} ).toThrow( type = "Auth.SiteNotFound" );
				} );

				it( "refuses an email already used on that site", function(){
					userRepo.$( "existsByEmailInScope", true );

					expect( function(){
						service.createUser( 1, "Ada", "ada@client.com", "correct-horse-battery" );
					} ).toThrow( type = "Auth.EmailAlreadyTaken" );
				} );

				it( "checks uniqueness within the site, not globally", function(){
					userRepo.$( "create", makeUser( 1, 1 ) );

					service.createUser( 1, "Ada", "ada@client.com", "correct-horse-battery" );

					var call = userRepo.$callLog().existsByEmailInScope[ 1 ];
					expect( call[ 1 ] ).toBe( "ada@client.com" );
					expect( call[ 2 ] ).toBe( 1 );
				} );

			} );

			describe( "creating a super admin", function(){

				it( "leaves the user with no site", function(){
					userRepo.$( "create", makeUser( 99 ) );

					service.createSuperAdmin( "Root", "root@platform.com", "correct-horse-battery" );

					var persisted = userRepo.$callLog().create[ 1 ][ 1 ];
					expect( persisted.isSuperAdmin() ).toBeTrue();
					expect( isNull( persisted.getSiteId() ) ).toBeTrue();
				} );

				it( "checks uniqueness in the super-admin scope only", function(){
					userRepo.$( "create", makeUser( 99 ) );

					service.createSuperAdmin( "Root", "root@platform.com", "correct-horse-battery" );

					// One argument only: no site scope was passed.
					var call = userRepo.$callLog().existsByEmailInScope[ 1 ];
					expect( isArray( call ) ? arrayLen( call ) : structCount( call ) ).toBe( 1 );
					expect( call[ 1 ] ).toBe( "root@platform.com" );
				} );

				it( "still enforces password strength", function(){
					expect( function(){
						service.createSuperAdmin( "Root", "root@platform.com", "short" );
					} ).toThrow( type = "Auth.WeakPassword" );
				} );

			} );

			describe( "passwords", function(){

				it( "verifies a correct password for an active user", function(){
					var hash = getInstance( "PasswordService@core" ).hashPassword( "correct-horse-battery" );
					var user = makeUser( 1, 1 ).setPasswordHash( hash );

					expect( service.verifyPassword( user, "correct-horse-battery" ) ).toBeTrue();
					expect( service.verifyPassword( user, "wrong-password-here" ) ).toBeFalse();
				} );

				it( "never verifies for an inactive user, even with the right password", function(){
					var hash = getInstance( "PasswordService@core" ).hashPassword( "correct-horse-battery" );
					var user = makeUser( 1, 1 ).setPasswordHash( hash ).setStatus( "inactive" );

					expect( service.verifyPassword( user, "correct-horse-battery" ) ).toBeFalse();
				} );

				it( "hashes on change and rejects a weak new password", function(){
					userRepo.$( "findById", makeUser( 1, 1 ) );

					service.changePassword( 1, "a-brand-new-passphrase" );

					var written = userRepo.$callLog().updatePasswordHash[ 1 ][ 2 ];
					expect( written ).toStartWith( "$2" );

					expect( function(){
						service.changePassword( 1, "short" );
					} ).toThrow( type = "Auth.WeakPassword" );
				} );

			} );

			describe( "assigning roles", function(){

				it( "assigns a role from the user's own site", function(){
					userRepo.$( "findById", makeUser( 1, 1 ) );
					roleRepo.$( "findById", makeRole( 10, 1, "editor" ) );

					service.assignRole( 1, 10 );

					var call = roleRepo.$callLog().assignRoleToUser[ 1 ];
					expect( call[ 1 ] ).toBe( 1 );
					expect( call[ 2 ] ).toBe( 10 );
					expect( call[ 3 ] ).toBe( 1 );
				} );

				it( "refuses a role belonging to another site", function(){
					userRepo.$( "findById", makeUser( 1, 1 ) );
					roleRepo.$( "findById", makeRole( 20, 2, "editor" ) );

					expect( function(){
						service.assignRole( 1, 20 );
					} ).toThrow( type = "Auth.CrossTenantRoleAssignment" );

					expect( roleRepo.$count( "assignRoleToUser" ) ).toBe( 0 );
				} );

				it( "refuses to give a super admin site roles", function(){
					userRepo.$( "findById", makeUser( 99 ) );
					roleRepo.$( "findById", makeRole( 10, 1, "editor" ) );

					expect( function(){
						service.assignRole( 99, 10 );
					} ).toThrow( type = "Auth.SuperAdminRolesUnsupported" );
				} );

				it( "rejects an unknown user or role", function(){
					userRepo.$( "findById" );
					expect( function(){
						service.assignRole( 999, 10 );
					} ).toThrow( type = "Auth.UserNotFound" );

					userRepo.$( "findById", makeUser( 1, 1 ) );
					roleRepo.$( "findById" );
					expect( function(){
						service.assignRole( 1, 999 );
					} ).toThrow( type = "Auth.RoleNotFound" );
				} );

			} );

		} );
	}

	private function makeSite( required numeric id ){
		return getInstance( "Site@core" ).setId( arguments.id ).setName( "Site" ).setSlug( "site-#arguments.id#" );
	}

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
