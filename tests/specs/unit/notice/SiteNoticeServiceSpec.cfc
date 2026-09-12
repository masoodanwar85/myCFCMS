/**
 * First-visit notice.
 *
 * The tests that matter are the refusals, and the proof that a stored value
 * which would not pass validation today never becomes a dialog. Copy is a
 * setting, not markup, for the same reason analytics stores an id rather than
 * a script.
 */
component extends="coldbox.system.testing.BaseTestCase" appMapping="/app" {

	function beforeAll(){
		super.beforeAll();
	}

	function afterAll(){
		super.afterAll();
	}

	function run(){
		describe( "SiteNoticeService", function(){

			beforeEach( function(){
				variables.stored = {};
				variables.notice = createMock( "core.models.notice.SiteNoticeService" )
					.setSiteSettingsRepo( settingsRepo() );
			} );

			function settingsRepo(){
				var repo = createStub();

				repo.$( "getValue" ).$callback( function( siteId, key, defaultValue = "" ){
					if ( structKeyExists( variables.stored, arguments.key ) ) {
						return variables.stored[ arguments.key ];
					}

					return arguments.defaultValue;
				} );

				repo.$( "put" ).$callback( function( siteId, key, value ){
					variables.stored[ arguments.key ] = arguments.value;
				} );

				return repo;
			}

			describe( "a site that has set nothing", function(){

				it( "is inactive, so a layout emits nothing", function(){
					expect( notice.noticeFor( 1 ).active ).toBeFalse();
				} );

				it( "reports the checkbox as off, not as missing", function(){
					expect( notice.isEnabled( 1 ) ).toBeFalse();
					expect( notice.settingsFor( 1 ).enabled ).toBeFalse();
				} );

			} );

			describe( "when it is on", function(){

				beforeEach( function(){
					notice.save(
						siteId    = 1,
						enabled   = true,
						heading   = "Special:",
						body      = "A reduced rate through 31 October 2026.",
						ctaUrl    = "/will",
						ctaLabel  = "Create your Will",
						expiresAt = dateFormat( dateAdd( "d", 30, now() ), "yyyy-mm-dd" )
					);
				} );

				it( "is active while the end date is still ahead", function(){
					expect( notice.noticeFor( 1 ).active ).toBeTrue();
					expect( notice.noticeFor( 1 ).heading ).toBe( "Special:" );
					expect( notice.noticeFor( 1 ).ctaUrl ).toBe( "/will" );
				} );

				it( "runs through the whole of the named day", function(){
					expect( notice.isExpired( dateFormat( now(), "yyyy-mm-dd" ) ) ).toBeFalse();
				} );

				it( "stops the day after the end date", function(){
					expect( notice.isExpired( dateFormat( dateAdd( "d", -1, now() ), "yyyy-mm-dd" ) ) ).toBeTrue();
				} );

				it( "is inactive once the end date has passed", function(){
					variables.stored[ "notice.expiresAt" ] = "2020-01-01";

					expect( notice.noticeFor( 1 ).active ).toBeFalse();
				} );

				it( "is inactive without a heading or a message", function(){
					variables.stored[ "notice.heading" ] = "";

					expect( notice.noticeFor( 1 ).active ).toBeFalse();
				} );

				it( "keeps a stored false, which ColdFusion considers falsy", function(){
					variables.stored[ "notice.enabled" ] = "false";

					expect( notice.isEnabled( 1 ) ).toBeFalse();
					expect( notice.noticeFor( 1 ).active ).toBeFalse();
				} );

			} );

			describe( "the button address", function(){

				it( "accepts a site-relative path", function(){
					expect( notice.isUsableUrl( "/will" ) ).toBeTrue();
				} );

				it( "accepts an absolute http(s) address", function(){
					expect( notice.isUsableUrl( "https://example.com/will" ) ).toBeTrue();
				} );

				it( "rejects a javascript: or data: address", function(){
					expect( notice.isUsableUrl( "javascript:alert(1)" ) ).toBeFalse();
					expect( notice.isUsableUrl( "data:text/html,hi" ) ).toBeFalse();
				} );

				it( "refuses to save one", function(){
					expect( function(){
						notice.save( siteId = 1, ctaUrl = "javascript:alert(1)" );
					} ).toThrow( type = "Notice.InvalidUrl" );
				} );

				it( "discards a stored address that would not pass validation today", function(){
					variables.stored[ "notice.enabled" ] = "true";
					variables.stored[ "notice.heading" ] = "Special:";
					variables.stored[ "notice.body" ]    = "Offer.";
					variables.stored[ "notice.ctaUrl" ]  = "javascript:alert(1)";

					expect( notice.noticeFor( 1 ).ctaUrl ).toBe( "" );
					expect( notice.noticeFor( 1 ).active ).toBeTrue();
				} );

			} );

			describe( "the end date", function(){

				it( "accepts a calendar day", function(){
					expect( notice.isCalendarDay( "2026-10-31" ) ).toBeTrue();
				} );

				it( "rejects anything that is not yyyy-mm-dd", function(){
					expect( notice.isCalendarDay( "31/10/2026" ) ).toBeFalse();
					expect( notice.isCalendarDay( "tomorrow" ) ).toBeFalse();
					expect( notice.isCalendarDay( "2026-13-40" ) ).toBeFalse();
				} );

				it( "refuses to save one", function(){
					expect( function(){
						notice.save( siteId = 1, expiresAt = "31 October 2026" );
					} ).toThrow( type = "Notice.InvalidDate" );
				} );

			} );

			describe( "length", function(){

				it( "refuses a heading longer than the dialog can hold", function(){
					expect( function(){
						notice.save( siteId = 1, heading = repeatString( "A", 81 ) );
					} ).toThrow( type = "Notice.InvalidInput" );
				} );

			} );

		} );
	}

}
