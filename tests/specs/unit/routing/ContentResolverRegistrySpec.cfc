/**
 * The seam that lets Core route to content it knows nothing about.
 *
 * What matters here is the contract feature modules rely on: priority order,
 * first-answer-wins, and the defaults Core fills in so themes can trust every
 * key to be present.
 */
component extends="coldbox.system.testing.BaseTestCase" appMapping="/app" {

	function beforeAll(){
		super.beforeAll();
	}

	function afterAll(){
		super.afterAll();
	}

	function run(){
		registry = "";

		describe( "ContentResolverRegistry", function(){

			beforeEach( function(){
				variables.injector = createStub();
				variables.registry = createMock( "core.models.routing.ContentResolverRegistry" )
					.init()
					.setWirebox( injector )
					.setLog( createStub().$( "warn" ).$( "debug" ) );
			} );

			describe( "registration", function(){

				it( "starts empty", function(){
					expect( registry.getRegistered() ).toBeEmpty();
				} );

				it( "registers a resolver", function(){
					registry.register( "PageContentResolver@pages" );

					expect( registry.getRegistered() ).toBe( [ "PageContentResolver@pages" ] );
				} );

				it( "ignores a repeat registration", function(){
					registry.register( "PageContentResolver@pages" );
					registry.register( "PageContentResolver@pages" );

					expect( registry.getRegistered().len() ).toBe( 1 );
				} );

				it( "unregisters, so removing a module removes its URLs", function(){
					registry.register( "PageContentResolver@pages" );
					registry.unregister( "PageContentResolver@pages" );

					expect( registry.getRegistered() ).toBeEmpty();
				} );

				it( "orders by priority, lowest first", function(){
					registry.register( "catchAll", 100 );
					registry.register( "specific", 10 );
					registry.register( "middle", 50 );

					expect( registry.getRegistered() ).toBe( [ "specific", "middle", "catchAll" ] );
				} );

			} );

			describe( "resolution", function(){

				it( "returns null when nothing is registered", function(){
					expect( isNull( registry.resolve( 1, "about" ) ) ).toBeTrue();
				} );

				it( "returns null when no resolver claims the path", function(){
					injector.$( "getInstance", createStub().$( "resolveContent" ) );
					registry.register( "silent" );

					expect( isNull( registry.resolve( 1, "about" ) ) ).toBeTrue();
				} );

				it( "returns the first answer", function(){
					injector.$( "getInstance", createStub().$( "resolveContent", { view : "page", title : "Found" } ) );
					registry.register( "answers" );

					expect( registry.resolve( 1, "about" ).title ).toBe( "Found" );
				} );

				it( "asks a higher-priority resolver first and stops there", function(){
					var specific = createStub().$( "resolveContent", { view : "blog", title : "Blog" } );
					var catchAll = createStub().$( "resolveContent", { view : "page", title : "Page" } );

					injector.$( "getInstance" ).$args( "specific" ).$results( specific );
					injector.$( "getInstance" ).$args( "catchAll" ).$results( catchAll );

					registry.register( "catchAll", 100 );
					registry.register( "specific", 10 );

					expect( registry.resolve( 1, "blog/hello" ).title ).toBe( "Blog" );
					expect( catchAll.$count( "resolveContent" ) ).toBe( 0 );
				} );

				it( "passes the site and path through to the resolver", function(){
					var resolver = createStub().$( "resolveContent", { view : "page" } );
					injector.$( "getInstance", resolver );
					registry.register( "answers" );

					registry.resolve( 42, "about/team" );

					var call = resolver.$callLog().resolveContent[ 1 ];
					expect( call[ 1 ] ).toBe( 42 );
					expect( call[ 2 ] ).toBe( "about/team" );
				} );

			} );

			describe( "normalising a resolution", function(){

				// Navigation is deliberately absent: it is site chrome and comes
				// from SiteNavigationRegistry, not from a content resolver.
				it( "fills in every key a theme may rely on", function(){
					injector.$( "getInstance", createStub().$( "resolveContent", { title : "Bare" } ) );
					registry.register( "sparse" );

					var result = registry.resolve( 1, "x" );

					expect( result.view ).toBe( "page" );
					expect( result.args ).toBeEmpty();
					expect( result.metaDescription ).toBe( "" );
					expect( result.statusCode ).toBe( 200 );
				} );

				it( "leaves values the resolver supplied alone", function(){
					injector.$( "getInstance", createStub().$(
						"resolveContent",
						{ view : "custom", statusCode : 410, title : "Gone" }
					) );
					registry.register( "opinionated" );

					var result = registry.resolve( 1, "x" );

					expect( result.view ).toBe( "custom" );
					expect( result.statusCode ).toBe( 410 );
				} );

			} );

		} );
	}

}
