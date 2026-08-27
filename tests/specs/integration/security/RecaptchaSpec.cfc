/**
 * reCAPTCHA configuration and verification.
 *
 * The specs that matter are the refusals and the one about the secret. A
 * service that leaks its secret key, or that waves a submission through when
 * it cannot verify it, is worse than having no reCAPTCHA at all — it looks
 * protected and is not.
 *
 * Nothing here calls Google. Verification against the live endpoint is checked
 * by hand; what is specced is every decision made before and after that call.
 *
 * Requires migrations to have run: `box migrate up`.
 */
component extends="coldbox.system.testing.BaseTestCase" appMapping="/app" {

	variables.PREFIX = "zzt-cap-";

	function beforeAll(){
		super.beforeAll();
		variables.captcha  = getInstance( "RecaptchaService@core" );
		variables.sites    = getInstance( "SiteService@core" );
		variables.settings = getInstance( "SiteSettingsRepository@core" );
		cleanup();
		variables.site = sites.createSite( name = "Captcha", slug = PREFIX & "one" );
	}

	function afterAll(){
		cleanup();
		super.afterAll();
	}

	function run(){
		describe( "reCAPTCHA", function(){

			beforeEach( function(){
				keys( "", "" );
			} );

			describe( "when it counts as configured", function(){

				it( "needs both keys", function(){
					expect( captcha.isConfigured( site.getId() ) ).toBeFalse( "neither key" );

					keys( "site-key", "" );
					expect( captcha.isConfigured( site.getId() ) ).toBeFalse( "site key alone" );

					keys( "", "secret-key" );
					expect( captcha.isConfigured( site.getId() ) ).toBeFalse( "secret alone" );

					keys( "site-key", "secret-key" );
					expect( captcha.isConfigured( site.getId() ) ).toBeTrue();
				} );

				it( "ignores whitespace-only keys", function(){
					keys( "   ", "   " );

					expect( captcha.isConfigured( site.getId() ) ).toBeFalse();
				} );

				it( "is decided per site", function(){
					var other = sites.createSite( name = "Captcha Two", slug = PREFIX & "two" );

					keys( "site-key", "secret-key" );

					expect( captcha.isConfigured( site.getId() ) ).toBeTrue();
					expect( captcha.isConfigured( other.getId() ) ).toBeFalse();
				} );

			} );

			describe( "the secret", function(){

				it( "can be reported as set without being readable", function(){
					keys( "site-key", "the-actual-secret" );

					expect( captcha.hasSecret( site.getId() ) ).toBeTrue();

					// There must be no public *method* returning it. `KEY_SECRET`
					// is excluded deliberately: it holds the settings key name
					// ("recaptcha.secretKey"), not the value.
					var exposed = getMetadata( captcha ).functions
						.filter( ( fn ) => reFindNoCase( "secret", fn.name )
							&& fn.name != "hasSecret"
							&& ( fn.access ?: "public" ) == "public" )
						.map( ( fn ) => fn.name );

					expect( exposed ).toBeEmpty( "no public method may return the secret: #exposed.toList( ', ' )#" );
				} );

				it( "never appears in the site key", function(){
					keys( "site-key", "the-actual-secret" );

					expect( captcha.getSiteKey( site.getId() ) ).toBe( "site-key" );
					expect( captcha.getSiteKey( site.getId() ) ).notToInclude( "the-actual-secret" );
				} );

			} );

			describe( "verifying", function(){

				it( "passes through when reCAPTCHA is not configured", function(){
					// A site that has not set it up must still be able to
					// receive enquiries.
					var result = captcha.verify( siteId = site.getId(), token = "" );

					expect( result.success ).toBeTrue();
					expect( result.configured ).toBeFalse();
				} );

				it( "refuses a missing token once configured", function(){
					keys( "site-key", "secret-key" );

					var result = captcha.verify( siteId = site.getId(), token = "" );

					expect( result.success ).toBeFalse();
					expect( result.configured ).toBeTrue();
					expect( result.error ).notToBeEmpty( "the visitor has to be told what to do" );
				} );

				it( "refuses a whitespace token", function(){
					keys( "site-key", "secret-key" );

					expect( captcha.verify( siteId = site.getId(), token = "   " ).success ).toBeFalse();
				} );

				it( "fails closed when the check cannot be completed", function(){
					// The condition under which verification matters most is
					// the one where an attacker can make it unavailable.
					keys( "site-key", "secret-key" );

					var offline = createMock( "core.models.security.RecaptchaService" )
						.setSettings( settings )
						.setLog( createStub().$( "warn" ).$( "error" ).$( "info" ) );

					offline.$( "callVerifyEndpoint" ).$throws( message = "connection refused" );

					var result = offline.verify( siteId = site.getId(), token = "looks-real" );

					expect( result.success ).toBeFalse();
					expect( result.error ).notToBeEmpty();
				} );

				it( "never reports Google's error codes to the visitor", function(){
					// `invalid-input-secret` tells an operator their key is
					// wrong and tells a visitor nothing they can act on.
					keys( "site-key", "secret-key" );

					var result = captcha.verify( siteId = site.getId(), token = "" );

					expect( result.error ).notToInclude( "invalid-input" );
					expect( result.error ).notToInclude( "secret" );
				} );

			} );

		} );
	}

	/* --------------------------------------------------------------------- */

	private function keys( required string siteKey, required string secret ){
		settings.put( site.getId(), captcha.KEY_SITE, arguments.siteKey );
		settings.put( site.getId(), captcha.KEY_SECRET, arguments.secret );

		return this;
	}

	private function cleanup(){
		queryExecute( "DELETE FROM sites WHERE slug LIKE :p", { p : PREFIX & "%" } );
	}

}
