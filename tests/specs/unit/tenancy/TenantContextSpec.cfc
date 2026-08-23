/**
 * Requirement 7: TenantContext holds the correct site.
 *
 * Also pins the isolation guarantee — one request's tenant must never be
 * visible to the next — because the context is a singleton and a leak here
 * would show one client's data on another client's site.
 */
component extends="coldbox.system.testing.BaseTestCase" appMapping="/app" {

	function beforeAll(){
		super.beforeAll();
		variables.context = getInstance( "TenantContext@core" );
	}

	function afterAll(){
		super.afterAll();
	}

	function run(){
		describe( "TenantContext", function(){

			beforeEach( function(){
				context.clear();
			} );

			afterEach( function(){
				context.clear();
			} );

			it( "starts empty", function(){
				expect( context.hasCurrentTenant() ).toBeFalse();
			} );

			it( "returns the exact site that was set", function(){
				var site = makeSite( 42, "Client One", "client-one" );

				context.setCurrentTenant( site );

				expect( context.hasCurrentTenant() ).toBeTrue();
				expect( context.getCurrentTenant().getId() ).toBe( 42 );
				expect( context.getCurrentTenant().getSlug() ).toBe( "client-one" );
				expect( context.getCurrentTenant().getName() ).toBe( "Client One" );
			} );

			it( "exposes the tenant id used to scope tenant-owned queries", function(){
				context.setCurrentTenant( makeSite( 7, "Seven", "seven" ) );
				expect( context.getCurrentTenantId() ).toBe( 7 );
			} );

			it( "throws rather than guessing when no tenant is resolved", function(){
				expect( function(){
					context.getCurrentTenant();
				} ).toThrow( type = "Tenancy.NoCurrentTenant" );
			} );

			it( "offers a null-returning read for callers that can cope without a tenant", function(){
				expect( isNull( context.getCurrentTenantOrNull() ) ).toBeTrue();

				context.setCurrentTenant( makeSite( 1, "One", "one" ) );

				expect( isNull( context.getCurrentTenantOrNull() ) ).toBeFalse();
			} );

			it( "replaces the tenant when set again", function(){
				context.setCurrentTenant( makeSite( 1, "One", "one" ) );
				context.setCurrentTenant( makeSite( 2, "Two", "two" ) );

				expect( context.getCurrentTenantId() ).toBe( 2 );
			} );

			it( "clears the tenant so a pooled thread cannot inherit it", function(){
				context.setCurrentTenant( makeSite( 1, "One", "one" ) );

				context.clear();

				expect( context.hasCurrentTenant() ).toBeFalse();
				expect( isNull( context.getCurrentTenantOrNull() ) ).toBeTrue();
			} );

		} );
	}

	private function makeSite( required numeric id, required string name, required string slug ){
		return getInstance( "Site@core" )
			.setId( arguments.id )
			.setName( arguments.name )
			.setSlug( arguments.slug );
	}

}
