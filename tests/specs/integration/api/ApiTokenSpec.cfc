/**
 * API credentials.
 *
 * A token is a long-lived credential that works outside the browser, so the
 * specs that matter are the refusals and the storage: that the plain token is
 * never in the database, and that revoking, expiry, deactivation and the wrong
 * site all stop it working.
 *
 * Requires migrations to have run: `box migrate up`.
 */
component extends="coldbox.system.testing.BaseTestCase" appMapping="/app" {

	variables.PREFIX = "zzt-api-";

	function beforeAll(){
		super.beforeAll();
		variables.tokens = getInstance( "ApiTokenService@core" );
		variables.sites  = getInstance( "SiteService@core" );
		variables.users  = getInstance( "UserService@core" );
		variables.roles  = getInstance( "RoleService@core" );
		cleanup();
		seed();
	}

	function afterAll(){
		cleanup();
		super.afterAll();
	}

	function run(){
		describe( "API tokens", function(){

			beforeEach( function( currentSpec ){
				setup();
			} );

			describe( "issuing one", function(){

				it( "returns the plain token exactly once", function(){
					var issued = tokens.issue( siteId = site.getId(), userId = owner.getId(), name = "CI" );

					expect( issued.getPlainToken() ).toStartWith( tokens.PREFIX );
					expect( len( issued.getPlainToken() ) ).toBeGT( 40 );

					// Read back from storage, the secret is gone for good.
					var reloaded = tokens.getForSite( site.getId() )
						.filter( ( t ) => t.getId() == issued.getId() )[ 1 ];

					expect( reloaded.getPlainToken() ).toBe( "" );
				} );

				it( "never stores the token itself", function(){
					var issued = tokens.issue( siteId = site.getId(), userId = owner.getId(), name = "Storage" );

					var row = queryExecute(
						"SELECT token_hash, prefix FROM api_tokens WHERE id = :id",
						{ id : issued.getId() }
					);

					// A database that leaks must not hand over working credentials.
					expect( row.token_hash ).notToBe( issued.getPlainToken() );
					expect( row.token_hash ).toBe( tokens.hashToken( issued.getPlainToken() ) );
					expect( issued.getPlainToken() ).toInclude( row.prefix );
				} );

				it( "produces a different token every time", function(){
					var a = tokens.issue( siteId = site.getId(), userId = owner.getId(), name = "A" );
					var b = tokens.issue( siteId = site.getId(), userId = owner.getId(), name = "B" );

					expect( a.getPlainToken() ).notToBe( b.getPlainToken() );
				} );

				it( "needs a name, so it can be recognised later", function(){
					expect( function(){
						tokens.issue( siteId = site.getId(), userId = owner.getId(), name = "  " );
					} ).toThrow( type = "Api.InvalidToken" );
				} );

				it( "refuses a user from another site", function(){
					expect( function(){
						tokens.issue( siteId = site.getId(), userId = stranger.getId(), name = "X" );
					} ).toThrow( type = "Api.CrossTenantUser" );
				} );

				it( "refuses an unknown site or user", function(){
					expect( function(){
						tokens.issue( siteId = 987654321, userId = owner.getId(), name = "X" );
					} ).toThrow( type = "Api.SiteNotFound" );

					expect( function(){
						tokens.issue( siteId = site.getId(), userId = 987654321, name = "X" );
					} ).toThrow( type = "Api.UserNotFound" );
				} );

			} );

			describe( "resolving one", function(){

				it( "identifies the user and site", function(){
					var issued   = tokens.issue( siteId = site.getId(), userId = owner.getId(), name = "Resolve" );
					var resolved = tokens.resolve( issued.getPlainToken() );

					expect( isNull( resolved ) ).toBeFalse();
					expect( resolved.user.getId() ).toBe( owner.getId() );
					expect( resolved.site.getId() ).toBe( site.getId() );
				} );

				it( "refuses anything that is not a token", function(){
					for ( var attempt in [ "", "   ", "cms_nope", "Bearer x", tokens.PREFIX & repeatString( "a", 64 ) ] ) {
						expect( isNull( tokens.resolve( attempt ) ) ).toBeTrue( "[#attempt#] must not resolve" );
					}
				} );

				it( "stops working the moment it is revoked", function(){
					var issued = tokens.issue( siteId = site.getId(), userId = owner.getId(), name = "Revoke" );

					expect( isNull( tokens.resolve( issued.getPlainToken() ) ) ).toBeFalse();

					tokens.revoke( issued.getId(), site.getId() );

					expect( isNull( tokens.resolve( issued.getPlainToken() ) ) ).toBeTrue();
				} );

				it( "stops working once it has expired", function(){
					var issued = tokens.issue(
						siteId    = site.getId(),
						userId    = owner.getId(),
						name      = "Expired",
						expiresAt = dateAdd( "d", -1, now() )
					);

					expect( isNull( tokens.resolve( issued.getPlainToken() ) ) ).toBeTrue();
				} );

				it( "stops working when the user is deactivated", function(){
					var temp   = users.createUser( site.getId(), "Temp", "temp@#PREFIX#one.test", "demo-password-123" );
					var issued = tokens.issue( siteId = site.getId(), userId = temp.getId(), name = "Temp" );

					expect( isNull( tokens.resolve( issued.getPlainToken() ) ) ).toBeFalse();

					users.deactivateUser( temp.getId() );

					// A token is the user's authority; suspending them suspends it.
					expect( isNull( tokens.resolve( issued.getPlainToken() ) ) ).toBeTrue();
				} );

			} );

			describe( "revoking", function(){

				it( "refuses to revoke another site's token", function(){
					var issued = tokens.issue( siteId = site.getId(), userId = owner.getId(), name = "Mine" );

					expect( function(){
						tokens.revoke( issued.getId(), other.getId() );
					} ).toThrow( type = "Api.TokenNotFound" );

					// And it still works, because nothing happened.
					expect( isNull( tokens.resolve( issued.getPlainToken() ) ) ).toBeFalse();
				} );

				it( "reports status separately for revoked and expired", function(){
					var revoked = tokens.issue( siteId = site.getId(), userId = owner.getId(), name = "R" );
					tokens.revoke( revoked.getId(), site.getId() );

					var expired = tokens.issue(
						siteId    = site.getId(),
						userId    = owner.getId(),
						name      = "E",
						expiresAt = dateAdd( "d", -1, now() )
					);

					var byId = {};
					for ( var t in tokens.getForSite( site.getId() ) ) {
						byId[ t.getId() ] = t;
					}

					// "Turned off" and "ran out" are different things to show
					// someone.
					expect( byId[ revoked.getId() ].getStatus() ).toBe( "revoked" );
					expect( byId[ expired.getId() ].getStatus() ).toBe( "expired" );
				} );

			} );

		} );
	}

	private function seed(){
		variables.site  = sites.createSite( name = "Api One", slug = PREFIX & "one" );
		variables.other = sites.createSite( name = "Api Two", slug = PREFIX & "two" );

		sites.addDomain( site.getId(), "#PREFIX#one.test", true );
		roles.seedDefaultRolesForSite( site.getId() );

		variables.owner = users.createUser( site.getId(), "Owner", "owner@#PREFIX#one.test", "demo-password-123" );
		users.assignRole( owner.getId(), roles.getRoleBySlugForSite( "owner", site.getId() ).getId() );

		variables.stranger = users.createUser( other.getId(), "Stranger", "s@#PREFIX#two.test", "demo-password-123" );
	}

	private function cleanup(){
		queryExecute( "DELETE FROM sites WHERE slug LIKE :p", { p : PREFIX & "%" } );
	}

}
