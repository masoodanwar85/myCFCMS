/**
 * The notice section of the Settings screen, through a real routed request.
 *
 * Requires migrations to have run: `box migrate up`.
 */
component extends="coldbox.system.testing.BaseTestCase" appMapping="/app" {

	variables.PREFIX   = "zzt-ns-";
	variables.PASSWORD = "correct-horse-battery";

	function beforeAll(){
		super.beforeAll();
		variables.sites  = getInstance( "SiteService@core" );
		variables.roles  = getInstance( "RoleService@core" );
		variables.users  = getInstance( "UserService@core" );
		variables.auth   = getInstance( "AuthenticationService@core" );
		variables.notice = getInstance( "SiteNoticeService@core" );
		cleanup();
		seed();
	}

	function afterAll(){
		auth.logout();
		cleanup();
		super.afterAll();
	}

	function run(){
		describe( "The notice screen", function(){

			beforeEach( function(){
				setup();
				auth.logout();
				signIn( variables.owner );
			} );

			afterEach( function(){
				auth.logout();
				notice.save( siteId = variables.site.getId() );
			} );

			it( "renders, with the fields", function(){
				var html = render( "/admin/settings" );

				expect( html ).toInclude( "Notice" );
				expect( html ).toInclude( 'name="noticeEnabled"' );
				expect( html ).toInclude( 'name="noticeHeading"' );
				expect( html ).toInclude( 'name="noticeBody"' );
				expect( html ).toInclude( 'action="/admin/settings/notice"' );
			} );

			it( "shows saved copy back", function(){
				notice.save(
					siteId  = site.getId(),
					enabled = true,
					heading = "Special:",
					body    = "A reduced rate through October."
				);

				var html = render( "/admin/settings" );

				expect( html ).toInclude( encodeForHTMLAttribute( "Special:" ) );
				expect( html ).toInclude( encodeForHTML( "A reduced rate through October." ) );
			} );

			/**
			 * The notice changes what every visitor sees, so it sits behind
			 * `site.settings.manage` — the same permission as branding.
			 * An editor can write content but cannot put a dialog on the site.
			 */
			describe( "saving it from the screen", function(){

				it( "goes live when the box is ticked, and comes back ticked", function(){
					// The exact journey a person takes: fill it in, tick the box,
					// save, come back. A checkbox that did not render `checked`
					// would look unticked on the next visit and save itself off
					// again — which is indistinguishable from "it does not work".
					adminRequest(
						uri    = "/admin/settings/notice",
						method = "POST",
						params = {
							csrfToken       : getInstance( "CsrfService@core" ).getCurrentToken(),
							noticeEnabled   : "on",
							noticeHeading   : "Black Friday",
							noticeBody      : "Estate packages half price.",
							noticeExpiresAt : dateFormat( dateAdd( "d", 14, now() ), "yyyy-mm-dd" )
						}
					);

					expect( notice.noticeFor( site.getId() ).active ).toBeTrue( "the notice did not go live" );

					var html = render( "/admin/settings" );

					expect( html ).toInclude( "checked" );
					expect( html ).toInclude( "showing" );
				} );

				it( "switches off when the box is left unticked, because a checkbox posts nothing", function(){
					// Not a bug, and the reason an apparently complete notice can
					// be dormant: an unticked box sends no field at all, so the
					// absence has to mean off.
					notice.save(
						siteId = site.getId(), enabled = true,
						heading = "Black Friday", body = "Estate packages half price."
					);
					expect( notice.noticeFor( site.getId() ).active ).toBeTrue();

					adminRequest(
						uri    = "/admin/settings/notice",
						method = "POST",
						params = {
							csrfToken     : getInstance( "CsrfService@core" ).getCurrentToken(),
							noticeHeading : "Black Friday",
							noticeBody    : "Estate packages half price."
						}
					);

					expect( notice.noticeFor( site.getId() ).active ).toBeFalse();
					expect( render( "/admin/settings" ) ).toInclude( "switched off" );
				} );

			} );

			describe( "the live state", function(){

				it( "says it is showing when it is", function(){
					notice.save(
						siteId  = site.getId(),
						enabled = true,
						heading = "Special offer",
						body    = "Half price wills until the end of the month."
					);

					var html = render( "/admin/settings" );

					expect( html ).toInclude( "showing" );
					expect( html ).notToInclude( "not showing" );
				} );

				it( "says it is not showing, and why, once the date has passed", function(){
					// The whole reason this line exists. A notice can be ticked,
					// filled in and completely dormant, and until the screen said
					// so the only symptom was "the notice does not work".
					notice.save(
						siteId    = site.getId(),
						enabled   = true,
						heading   = "Special offer",
						body      = "Half price wills until the end of the month.",
						expiresAt = "2020-01-31"
					);

					var html = render( "/admin/settings" );

					expect( html ).toInclude( "not showing" );
					expect( html ).toInclude( "2020-01-31" );
					expect( html ).toInclude( "has passed" );
				} );

				it( "says it is switched off when the box is unticked", function(){
					notice.save(
						siteId  = site.getId(),
						enabled = false,
						heading = "Special offer",
						body    = "Half price wills until the end of the month."
					);

					var html = render( "/admin/settings" );

					expect( html ).toInclude( "not showing" );
					expect( html ).toInclude( "switched off" );
				} );

				it( "says what is missing when the copy is incomplete", function(){
					notice.save( siteId = site.getId(), enabled = true, heading = "Special offer", body = "" );

					var html = render( "/admin/settings" );

					expect( html ).toInclude( "not showing" );
					expect( html ).toInclude( "heading and a message" );
				} );

			} );

			it( "is refused to a user whose role does not grant it", function(){
				auth.logout();
				signIn( variables.editor );

				var event = adminRequest(
					uri    = "/admin/settings/notice",
					method = "POST",
					params = { noticeEnabled : "on", noticeHeading : "Hacked" }
				);

				expect( event.getRenderedContent() ).notToInclude( "Notice saved" );
				expect( notice.settingsFor( site.getId() ).heading ).toBe( "" );
			} );

		} );
	}

	/* --------------------------------------------------------------------- */

	private function adminRequest(
		required string uri,
		string method = "GET",
		struct params = {}
	){
		setup();

		return this.request(
			route   = arguments.uri,
			params  = arguments.params,
			headers = { "Host" : "#PREFIX#one.test" },
			method  = arguments.method
		);
	}

	private string function render( required string uri ){
		var event = adminRequest( uri = arguments.uri );

		return event.getRenderedContent() & ( event.getHandlerResults() ?: "" );
	}

	private function signIn( required any user ){
		getInstance( "TenantContext@core" ).setCurrentTenant( variables.site );
		auth.startSessionFor( arguments.user, variables.site.getId() );

		return this;
	}

	private function seed(){
		variables.site = sites.createSite( name = "Notice Screen Test", slug = PREFIX & "one" );
		sites.addDomain( site.getId(), "#PREFIX#one.test" );
		roles.seedDefaultRolesForSite( site.getId() );

		variables.owner = users.createUser( site.getId(), "Owner", "owner@notice.test", PASSWORD );
		users.assignRole( owner.getId(), roles.getRoleBySlugForSite( "owner", site.getId() ).getId() );

		variables.editor = users.createUser( site.getId(), "Editor", "editor@notice.test", PASSWORD );
		users.assignRole( editor.getId(), roles.getRoleBySlugForSite( "editor", site.getId() ).getId() );
	}

	private function cleanup(){
		queryExecute( "DELETE FROM sites WHERE slug LIKE :p", { p : PREFIX & "%" } );
	}

}
