/**
 * The seam that makes a site's menu the site's, rather than the property of
 * whichever module answered the URL.
 */
component extends="coldbox.system.testing.BaseTestCase" appMapping="/app" {

	function beforeAll(){
		super.beforeAll();
	}

	function afterAll(){
		super.afterAll();
	}

	function run(){
		describe( "SiteNavigationRegistry", function(){

			beforeEach( function(){
				variables.injector = createStub();
				variables.registry = createMock( "core.models.routing.SiteNavigationRegistry" )
					.init()
					.setWirebox( injector )
					.setLog( createStub().$( "warn" ).$( "debug" ) );
			} );

			describe( "registration", function(){

				it( "starts empty", function(){
					expect( registry.getRegistered() ).toBeEmpty();
					expect( registry.getNavigationFor( 1 ) ).toBeEmpty();
				} );

				it( "registers a provider once", function(){
					registry.register( "PageNavigationProvider@pages" );
					registry.register( "PageNavigationProvider@pages" );

					expect( registry.getRegistered().len() ).toBe( 1 );
				} );

				it( "unregisters, so removing a module removes its menu entries", function(){
					registry.register( "BlogNavigationProvider@blog" );
					registry.unregister( "BlogNavigationProvider@blog" );

					expect( registry.getRegistered() ).toBeEmpty();
				} );

				it( "keeps providers in priority order", function(){
					registry.register( "late", 90 );
					registry.register( "early", 10 );

					expect( registry.getRegistered() ).toBe( [ "early", "late" ] );
				} );

			} );

			describe( "building a menu", function(){

				it( "merges items from every provider", function(){
					injector.$( "getInstance" ).$args( "pages" ).$results(
						createStub().$( "getNavigationItems", [ { label : "About", href : "/about", order : 1 } ] )
					);
					injector.$( "getInstance" ).$args( "blog" ).$results(
						createStub().$( "getNavigationItems", [ { label : "Blog", href : "/blog", order : 500 } ] )
					);

					registry.register( "pages", 10 );
					registry.register( "blog", 50 );

					var menu = registry.getNavigationFor( 1 );

					expect( menu.len() ).toBe( 2 );
					expect( menu[ 1 ].label ).toBe( "About" );
					expect( menu[ 2 ].label ).toBe( "Blog" );
				} );

				it( "sorts by each item's own order, not by provider", function(){
					injector.$( "getInstance" ).$args( "second" ).$results(
						createStub().$( "getNavigationItems", [ { label : "Later", href : "/l", order : 9 } ] )
					);
					injector.$( "getInstance" ).$args( "first" ).$results(
						createStub().$( "getNavigationItems", [ { label : "Sooner", href : "/s", order : 1 } ] )
					);

					// Registered so the high-order item's provider runs first.
					registry.register( "second", 10 );
					registry.register( "first", 90 );

					expect( registry.getNavigationFor( 1 ).map( ( i ) => i.label ) ).toBe( [ "Sooner", "Later" ] );
				} );

				it( "keeps an order of zero first", function(){
					// ColdFusion's `?:` treats 0 as absent, which would have sent
					// the first item in a menu to the back.
					injector.$( "getInstance", createStub().$( "getNavigationItems", [
						{ label : "Second", href : "/b", order : 1 },
						{ label : "Home",   href : "/",  order : 0 }
					] ) );
					registry.register( "pages" );

					expect( registry.getNavigationFor( 1 ).map( ( i ) => i.label ) ).toBe( [ "Home", "Second" ] );
				} );

				it( "breaks ties on label", function(){
					injector.$( "getInstance", createStub().$( "getNavigationItems", [
						{ label : "Zebra", href : "/z", order : 5 },
						{ label : "Apple", href : "/a", order : 5 }
					] ) );
					registry.register( "pages" );

					expect( registry.getNavigationFor( 1 ).map( ( i ) => i.label ) ).toBe( [ "Apple", "Zebra" ] );
				} );

				it( "defaults a missing order rather than failing", function(){
					injector.$( "getInstance", createStub().$( "getNavigationItems", [ { label : "Bare", href : "/x" } ] ) );
					registry.register( "pages" );

					expect( registry.getNavigationFor( 1 )[ 1 ].order ).toBe( 100 );
				} );

				it( "passes the site through to each provider", function(){
					var provider = createStub().$( "getNavigationItems", [] );
					injector.$( "getInstance", provider );
					registry.register( "pages" );

					registry.getNavigationFor( 42 );

					expect( provider.$callLog().getNavigationItems[ 1 ][ 1 ] ).toBe( 42 );
				} );

				it( "skips a broken provider instead of taking the site down", function(){
					injector.$( "getInstance" ).$args( "broken" ).$results(
						createStub().$( "getNavigationItems" ).$throws( type = "Boom", message = "nope" )
					);
					injector.$( "getInstance" ).$args( "working" ).$results(
						createStub().$( "getNavigationItems", [ { label : "Fine", href : "/f", order : 1 } ] )
					);

					registry.register( "broken", 10 );
					registry.register( "working", 20 );

					var menu = registry.getNavigationFor( 1 );

					expect( menu.len() ).toBe( 1 );
					expect( menu[ 1 ].label ).toBe( "Fine" );
				} );

			} );

		} );
	}

}
