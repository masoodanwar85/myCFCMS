/**
 * Theme selection and rendering.
 *
 * These run against the real themes on disk, because "is this theme installed?"
 * is a filesystem question and stubbing it away would test nothing.
 */
component extends="coldbox.system.testing.BaseTestCase" appMapping="/app" {

	function beforeAll(){
		super.beforeAll();
	}

	function afterAll(){
		super.afterAll();
	}

	function run(){
		describe( "ThemeService", function(){

			beforeEach( function(){
				variables.settingsRepo = createStub().$( "getValue", "" ).$( "put" );

				variables.themes = createMock( "core.models.theme.ThemeService" )
					.setSiteSettingsRepo( settingsRepo )
					.setSettings( { "defaultTheme" : "default", "themeSettingKey" : "theme" } )
					.setRenderer( getInstance( "coldbox:renderer" ) )
					.setWirebox( getWireBox() )
					.setLog( createStub().$( "warn" ).$( "debug" ) );
			} );

			describe( "installed themes", function(){

				it( "sees the themes shipped in /themes", function(){
					expect( themes.themeExists( "default" ) ).toBeTrue();
					expect( themes.themeExists( "starter" ) ).toBeTrue();
				} );

				it( "does not invent one that is absent", function(){
					expect( themes.themeExists( "no-such-theme" ) ).toBeFalse();
				} );

				it( "lists them", function(){
					var slugs = themes.getInstalledThemes().map( ( t ) => t.getSlug() );

					expect( slugs ).toInclude( "default" );
					expect( slugs ).toInclude( "starter" );
				} );

				it( "reads the manifest", function(){
					var theme = themes.getTheme( "default" );

					expect( theme.getTitle() ).toBe( "Default" );
					expect( theme.getVersion() ).toBe( "1.0.0" );
				} );

				it( "throws for a theme that is not installed", function(){
					expect( function(){
						themes.getTheme( "no-such-theme" );
					} ).toThrow( type = "Theme.NotInstalled" );
				} );

			} );

			describe( "slug handling", function(){

				it( "strips anything that could climb out of the themes directory", function(){
					expect( themes.normalizeSlug( "../../etc" ) ).toBe( "etc" );
					expect( themes.normalizeSlug( "de/fault" ) ).toBe( "default" );
					expect( themes.normalizeSlug( "  Default  " ) ).toBe( "default" );
				} );

				it( "refuses a traversal attempt as simply not installed", function(){
					expect( themes.themeExists( "../themes" ) ).toBeFalse();
				} );

			} );

			describe( "choosing a site's theme", function(){

				it( "uses the default when a site has chosen none", function(){
					expect( themes.getThemeForSite( 1 ).getSlug() ).toBe( "default" );
				} );

				it( "uses the site's choice", function(){
					settingsRepo.$( "getValue", "starter" );

					expect( themes.getThemeForSite( 1 ).getSlug() ).toBe( "starter" );
				} );

				it( "falls back rather than failing when the chosen theme is gone", function(){
					settingsRepo.$( "getValue", "uninstalled-theme" );

					// A missing theme must not take a client's whole site offline.
					expect( themes.getThemeForSite( 1 ).getSlug() ).toBe( "default" );
				} );

				it( "records a choice as a site setting", function(){
					themes.setThemeForSite( 7, "starter" );

					var call = settingsRepo.$callLog().put[ 1 ];
					expect( call[ 1 ] ).toBe( 7 );
					expect( call[ 2 ] ).toBe( "theme" );
					expect( call[ 3 ] ).toBe( "starter" );
				} );

				it( "refuses to record a theme that is not installed", function(){
					expect( function(){
						themes.setThemeForSite( 7, "no-such-theme" );
					} ).toThrow( type = "Theme.NotInstalled" );
				} );

			} );

			describe( "template paths", function(){

				it( "knows which views and layouts a theme provides", function(){
					var theme = themes.getTheme( "default" );

					expect( theme.hasView( "page" ) ).toBeTrue();
					expect( theme.hasView( "404" ) ).toBeTrue();
					expect( theme.hasView( "nonexistent" ) ).toBeFalse();
					expect( theme.hasLayout( "main" ) ).toBeTrue();
				} );

				it( "builds mapped paths, not disk paths", function(){
					var theme = themes.getTheme( "default" );

					expect( theme.viewPath( "page" ) ).toBe( "/themes/default/views/page" );
					expect( theme.layoutPath( "main" ) ).toBe( "/themes/default/layouts/main" );
				} );

				it( "throws for a view the theme does not provide", function(){
					expect( function(){
						themes.renderView( themes.getTheme( "default" ), "nonexistent", {} );
					} ).toThrow( type = "Theme.ViewMissing" );
				} );

			} );

		} );
	}

}
