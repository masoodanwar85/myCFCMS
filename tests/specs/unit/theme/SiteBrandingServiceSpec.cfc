/**
 * Per-site branding.
 *
 * The tests that matter most here are the negative ones. These values are
 * written by a client through a settings form and end up inside a `<style>`
 * block and an `src` attribute, so the question is not "does a hex colour work"
 * but "what happens when someone types something that is not one".
 */
component extends="coldbox.system.testing.BaseTestCase" appMapping="/app" {

	function beforeAll(){
		super.beforeAll();
	}

	function afterAll(){
		super.afterAll();
	}

	function run(){
		describe( "SiteBrandingService", function(){

			beforeEach( function(){
				variables.stored = {};
				variables.branding = createMock( "core.models.theme.SiteBrandingService" )
					.setSiteSettingsRepo( settingsRepo() );
			} );

			/**
			 * A settings repository backed by `variables.stored`, so a spec can
			 * seed values by key and read back what `save()` wrote.
			 */
			function settingsRepo(){
				var repo = createStub().$( "getValue", "" ).$( "put" );

				var keys = [
					"branding.logoUrl",
					"branding.colorPrimary",
					"branding.colorAccent",
					"branding.fontHeading",
					"branding.fontBody"
				];

				for ( var key in keys ) {
					repo.$( "getValue" )
						.$args( 1, key, "" )
						.$results( variables.stored[ key ] ?: "" );
				}

				return repo;
			}

			describe( "a site that has set nothing", function(){

				it( "produces no style block, so the theme's own defaults stand", function(){
					expect( branding.styleBlockFor( 1 ) ).toBe( "" );
				} );

				it( "reports no logo rather than a broken one", function(){
					expect( branding.logoUrlFor( 1 ) ).toBe( "" );
				} );

			} );

			describe( "colours", function(){

				it( "accepts three, six and eight digit hex", function(){
					expect( branding.isValidColor( "##fff" ) ).toBeTrue();
					expect( branding.isValidColor( "##0f2a4a" ) ).toBeTrue();
					expect( branding.isValidColor( "##0f2a4aff" ) ).toBeTrue();
				} );

				it( "rejects anything that is not a hex literal", function(){
					expect( branding.isValidColor( "red" ) ).toBeFalse();
					expect( branding.isValidColor( "rgb(0,0,0)" ) ).toBeFalse();
					expect( branding.isValidColor( "0f2a4a" ) ).toBeFalse();
					expect( branding.isValidColor( "" ) ).toBeFalse();
				} );

				it( "refuses to save a colour that would escape the declaration", function(){
					expect( function(){
						branding.save( siteId = 1, colorPrimary = "##fff;} body{display:none}" );
					} ).toThrow( type = "Branding.InvalidColor" );
				} );

				it( "emits a custom property when one is set", function(){
					variables.stored[ "branding.colorPrimary" ] = "##0f2a4a";
					branding.setSiteSettingsRepo( settingsRepo() );

					expect( branding.styleBlockFor( 1 ) ).toBe( ":root{--brand-primary: ##0f2a4a;}" );
				} );

			} );

			describe( "fonts", function(){

				it( "accepts a family stack with quotes and commas", function(){
					expect( branding.isValidFont( "'Source Serif 4', Georgia, serif" ) ).toBeTrue();
				} );

				it( "rejects anything carrying CSS syntax", function(){
					expect( branding.isValidFont( "Inter; color:red" ) ).toBeFalse();
					expect( branding.isValidFont( "url(evil.css)" ) ).toBeFalse();
					expect( branding.isValidFont( "Inter}body{display:none" ) ).toBeFalse();
				} );

			} );

			describe( "the logo address", function(){

				it( "accepts a site-relative media URL", function(){
					expect( branding.isUsableUrl( "/media/2026/09/logo-a1b2.png" ) ).toBeTrue();
				} );

				it( "accepts an absolute http(s) address", function(){
					expect( branding.isUsableUrl( "https://cdn.example.com/logo.png" ) ).toBeTrue();
				} );

				it( "rejects a javascript: or data: address", function(){
					expect( branding.isUsableUrl( "javascript:alert(1)" ) ).toBeFalse();
					expect( branding.isUsableUrl( "data:image/svg+xml;base64,PHN2Zz4=" ) ).toBeFalse();
				} );

				it( "rejects a protocol-relative address, which inherits the page's scheme", function(){
					expect( branding.isUsableUrl( "//evil.example.com/logo.png" ) ).toBeFalse();
				} );

				/**
				 * The prefix being valid is not enough. Output encoding would
				 * contain this anyway, but a validator that accepts it is
				 * relying on the layer above to be perfect.
				 */
				it( "rejects a valid prefix followed by an attribute break", function(){
					expect( branding.isUsableUrl( 'https://x" onerror="alert(1)' ) ).toBeFalse();
					expect( branding.isUsableUrl( "/media/x.png'><script>" ) ).toBeFalse();
					expect( branding.isUsableUrl( "/media/a b.png" ) ).toBeFalse();
				} );

				it( "refuses to save one", function(){
					expect( function(){
						branding.save( siteId = 1, logoUrl = "javascript:alert(1)" );
					} ).toThrow( type = "Branding.InvalidUrl" );
				} );

			} );

			describe( "defence in depth", function(){

				/**
				 * `save()` is not the only way a row reaches `site_settings` —
				 * a migration, a seed, or a direct UPDATE can all put one there.
				 * The read path re-validates rather than trusting that whatever
				 * wrote the row went through this service.
				 */
				it( "discards a stored value that would not pass validation today", function(){
					variables.stored[ "branding.colorPrimary" ] = "red;} body{display:none";
					variables.stored[ "branding.fontBody" ]     = "url(//evil/x.css)";
					branding.setSiteSettingsRepo( settingsRepo() );

					var result = branding.brandingFor( 1 );

					expect( result.colorPrimary ).toBe( "" );
					expect( result.fontBody ).toBe( "" );
					expect( result.styles ).toBe( "" );
				} );

				it( "discards a stored logo address that is not http(s) or relative", function(){
					variables.stored[ "branding.logoUrl" ] = "javascript:alert(1)";
					branding.setSiteSettingsRepo( settingsRepo() );

					expect( branding.logoUrlFor( 1 ) ).toBe( "" );
				} );

			} );

		} );
	}

}
