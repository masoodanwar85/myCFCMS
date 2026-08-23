/**
 * Requirement 7 at the request level, plus requirement 6's unknown-domain case.
 *
 * Drives the real registered interceptor against real rows, so this covers the
 * whole documented flow in one pass:
 *
 *   Request → resolve domain → find site → TenantContext → execute request
 *
 * Requires migrations to have run: `box migrate up`.
 */
component extends="coldbox.system.testing.BaseTestCase" appMapping="/app" {

	variables.PREFIX = "zzt-int-";

	function beforeAll(){
		super.beforeAll();
		variables.service       = getInstance( "SiteService@core" );
		variables.tenantContext = getInstance( "TenantContext@core" );
		variables.interceptor   = getController()
			.getInterceptorService()
			// ColdBox registers a module's interceptors as `<name>@<module>`.
			.getInterceptor( "TenantInterceptor@core" );
		cleanup();
	}

	function afterAll(){
		cleanup();
		tenantContext.clear();
		super.afterAll();
	}

	function run(){
		describe( "TenantInterceptor", function(){

			beforeEach( function(){
				setup();
				tenantContext.clear();
			} );

			afterEach( function(){
				tenantContext.clear();
				cleanup();
			} );

			it( "puts the right site into TenantContext for a known host", function(){
				var site = seedSite( "Alpha", "#PREFIX#alpha.com" );
				var prc  = {};

				interceptor.preProcess(
					event         = hostEvent( "#PREFIX#alpha.com" ),
					interceptData = {},
					rc            = {},
					prc           = prc
				);

				expect( tenantContext.hasCurrentTenant() ).toBeTrue();
				expect( tenantContext.getCurrentTenantId() ).toBe( site.getId() );
				expect( tenantContext.getCurrentTenant().getName() ).toBe( "Alpha" );
			} );

			it( "also exposes the site on prc for views and handlers", function(){
				var site = seedSite( "Bravo", "#PREFIX#bravo.com" );
				var prc  = {};

				interceptor.preProcess(
					event         = hostEvent( "#PREFIX#bravo.com" ),
					interceptData = {},
					rc            = {},
					prc           = prc
				);

				expect( prc ).toHaveKey( "currentSite" );
				expect( prc.currentSite.getId() ).toBe( site.getId() );
			} );

			it( "resolves through a port and mixed case, as a real Host header arrives", function(){
				var site = seedSite( "Charlie", "#PREFIX#charlie.com" );
				var prc  = {};

				interceptor.preProcess(
					event         = hostEvent( "#uCase( PREFIX )#CHARLIE.com:8080" ),
					interceptData = {},
					rc            = {},
					prc           = prc
				);

				expect( tenantContext.getCurrentTenantId() ).toBe( site.getId() );
			} );

			it( "picks the right tenant when several sites exist", function(){
				var alpha = seedSite( "Alpha", "#PREFIX#alpha.com" );
				var bravo = seedSite( "Bravo", "#PREFIX#bravo.com" );
				var prc   = {};

				interceptor.preProcess(
					event         = hostEvent( "#PREFIX#bravo.com" ),
					interceptData = {},
					rc            = {},
					prc           = prc
				);

				expect( tenantContext.getCurrentTenantId() ).toBe( bravo.getId() );
				expect( tenantContext.getCurrentTenantId() ).notToBe( alpha.getId() );
			} );

			it( "leaves the context empty for an unknown host, without failing the request", function(){
				var prc = {};

				interceptor.preProcess(
					event         = hostEvent( "#PREFIX#nobody.example" ),
					interceptData = {},
					rc            = {},
					prc           = prc
				);

				expect( tenantContext.hasCurrentTenant() ).toBeFalse();
				expect( prc ).notToHaveKey( "currentSite" );
			} );

			it( "reports the missing tenant clearly when something asks for one", function(){
				interceptor.preProcess(
					event         = hostEvent( "#PREFIX#nobody.example" ),
					interceptData = {},
					rc            = {},
					prc           = {}
				);

				expect( function(){
					tenantContext.getCurrentTenant();
				} ).toThrow( type = "Tenancy.NoCurrentTenant" );
			} );

			it( "clears a previous request's tenant before resolving", function(){
				var alpha = seedSite( "Alpha", "#PREFIX#alpha.com" );

				// Pretend a prior request on this thread left its tenant behind.
				tenantContext.setCurrentTenant( alpha );

				interceptor.preProcess(
					event         = hostEvent( "#PREFIX#nobody.example" ),
					interceptData = {},
					rc            = {},
					prc           = {}
				);

				expect( tenantContext.hasCurrentTenant() ).toBeFalse();
			} );

			it( "stops resolving a site once it is deactivated", function(){
				var site = seedSite( "Delta", "#PREFIX#delta.com" );

				getInstance( "SiteRepository@core" ).update( site.setStatus( "inactive" ) );

				interceptor.preProcess(
					event         = hostEvent( "#PREFIX#delta.com" ),
					interceptData = {},
					rc            = {},
					prc           = {}
				);

				expect( tenantContext.hasCurrentTenant() ).toBeFalse();
			} );

		} );
	}

	/**
	 * A stand-in for the ColdBox request context that reports one Host header.
	 */
	private function hostEvent( required string host ){
		return createStub().$( "getHTTPHeader", arguments.host );
	}

	private function seedSite( required string name, required string domain ){
		var site = service.createSite(
			name = arguments.name,
			slug = PREFIX & service.slugify( arguments.name ) & "-" & createUUID().left( 8 )
		);

		service.addDomain( site.getId(), arguments.domain );

		return site;
	}

	private function cleanup(){
		queryExecute( "DELETE FROM sites WHERE slug LIKE :prefix", { prefix : PREFIX & "%" } );
	}

}
