/**
 * A theme's static asset URLs.
 *
 * Templates and assets deliberately live in different places: `/themes` is
 * outside the webroot because a layout is an executable `.cfm`, while CSS and
 * JS have to be reachable by the browser. `assetUrl()` is the single place that
 * knows the difference.
 */
component extends="coldbox.system.testing.BaseTestCase" appMapping="/app" {

	function beforeAll(){
		super.beforeAll();
	}

	function afterAll(){
		super.afterAll();
	}

	function run(){
		describe( "Theme asset URLs", function(){

			beforeEach( function(){
				variables.theme = getInstance( "Theme@core" )
					.setSlug( "willcreator" )
					.setMappedPath( "/themes/willcreator" )
					.setDiskPath( expandPath( "/themes/willcreator" ) );
			} );

			it( "points at the webroot, not at the template directory", function(){
				expect( theme.assetUrl( "css/theme.css" ) )
					.toBe( "/assets/themes/willcreator/css/theme.css" );
			} );

			it( "does not care whether the caller wrote a leading slash", function(){
				expect( theme.assetUrl( "/css/theme.css" ) )
					.toBe( "/assets/themes/willcreator/css/theme.css" );
			} );

			it( "keeps a theme inside its own directory", function(){
				expect( theme.assetUrl( "../../../public/Application.cfc" ) )
					.notToInclude( ".." );
			} );

			it( "collapses repeated slashes rather than emitting them", function(){
				expect( theme.assetUrl( "css//theme.css" ) )
					.toBe( "/assets/themes/willcreator/css/theme.css" );
			} );

			it( "reports whether the file is actually deployed", function(){
				expect( theme.hasAsset( "css/theme.css" ) ).toBeTrue();
				expect( theme.hasAsset( "css/nothing-here.css" ) ).toBeFalse();
			} );

		} );
	}

}
