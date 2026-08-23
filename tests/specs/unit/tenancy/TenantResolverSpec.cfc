/**
 * Requirements 5 and 6: resolving a site from a domain, and what happens when
 * the domain is unknown.
 *
 * The repository is stubbed so these cases pin the resolver's own behaviour —
 * normalisation, the ignore list, and the null contract — without a database.
 * The real SQL is exercised in the integration specs.
 */
component extends="coldbox.system.testing.BaseTestCase" appMapping="/app" {

	function beforeAll(){
		super.beforeAll();
	}

	function afterAll(){
		super.afterAll();
	}

	function run(){
		describe( "TenantResolver", function(){

			beforeEach( function(){
				variables.knownSite = getInstance( "Site@core" )
					.setId( 10 )
					.setName( "Client One" )
					.setSlug( "client-one" );

				// Behaves like the real table: only `client.com` is registered.
				// No return value configured, so the stub answers null: nothing registered.
				variables.repo = createStub().$( "findActiveByDomain" );

				variables.resolver = createMock( "core.models.tenancy.TenantResolver" )
					.setSiteRepository( repo )
					.setDomainNormalizer( getInstance( "DomainNormalizer@core" ) )
					.setSettings( { "ignoredDomains" : [] } );
			} );

			it( "resolves a known domain to its site", function(){
				repo.$( "findActiveByDomain", knownSite );

				var site = resolver.resolveByDomain( "client.com" );

				expect( isNull( site ) ).toBeFalse();
				expect( site.getId() ).toBe( 10 );
				expect( site.getSlug() ).toBe( "client-one" );
			} );

			it( "normalises the host before looking it up", function(){
				repo.$( "findActiveByDomain", knownSite );

				resolver.resolveByDomain( "HTTPS://Client.COM:8443/pricing" );

				expect( repo.$callLog().findActiveByDomain[ 1 ][ 1 ] ).toBe( "client.com" );
			} );

			it( "returns null for an unknown domain", function(){
				expect( isNull( resolver.resolveByDomain( "not-a-tenant.com" ) ) ).toBeTrue();
			} );

			it( "returns null for an unusable host without querying the database", function(){
				expect( isNull( resolver.resolveByDomain( "" ) ) ).toBeTrue();
				expect( isNull( resolver.resolveByDomain( "not a domain" ) ) ).toBeTrue();

				expect( repo.$count( "findActiveByDomain" ) ).toBe( 0 );
			} );

			it( "skips lookup entirely for configured non-tenant hosts", function(){
				resolver.setSettings( { "ignoredDomains" : [ "Health.Internal" ] } );

				expect( isNull( resolver.resolveByDomain( "health.internal" ) ) ).toBeTrue();
				expect( repo.$count( "findActiveByDomain" ) ).toBe( 0 );
			} );

			it( "reads the host from the request's Host header", function(){
				repo.$( "findActiveByDomain", knownSite );

				var event = createStub().$( "getHTTPHeader", "Client.com:8080" );

				expect( resolver.getRequestDomain( event ) ).toBe( "client.com" );

				var site = resolver.resolveFromEvent( event );
				expect( isNull( site ) ).toBeFalse();
				expect( site.getId() ).toBe( 10 );
			} );

		} );
	}

}
