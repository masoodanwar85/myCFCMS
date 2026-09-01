/**
 * The branding section of the Settings screen, through a real routed request.
 *
 * There was no integration cover over the settings *view* before this, which is
 * how a template error there could reach production unseen — the handler
 * compiles, the tests pass, and the screen 500s. These render it.
 *
 * Requires migrations to have run: `box migrate up`.
 */
component extends="coldbox.system.testing.BaseTestCase" appMapping="/app" {

	variables.PREFIX   = "zzt-br-";
	variables.PASSWORD = "correct-horse-battery";

	function beforeAll(){
		super.beforeAll();
		variables.sites    = getInstance( "SiteService@core" );
		variables.roles    = getInstance( "RoleService@core" );
		variables.users    = getInstance( "UserService@core" );
		variables.auth     = getInstance( "AuthenticationService@core" );
		variables.branding = getInstance( "SiteBrandingService@core" );
		cleanup();
		seed();
	}

	function afterAll(){
		auth.logout();
		cleanup();
		super.afterAll();
	}

	function run(){
		describe( "The branding screen", function(){

			beforeEach( function(){
				setup();
				auth.logout();
				signIn( variables.owner );
			} );

			afterEach( function(){
				auth.logout();
			} );

			it( "renders, with the fields and the picker hook", function(){
				var html = render( "/admin/settings" );

				expect( html ).toInclude( "Branding" );
				expect( html ).toInclude( 'name="logoUrl"' );
				expect( html ).toInclude( 'name="colorPrimary"' );
				expect( html ).toInclude( 'data-pick-media="logoUrl"' );
			} );

			it( "shows no logo preview until one is set", function(){
				expect( render( "/admin/settings" ) ).toInclude( "No logo set" );
			} );

			describe( "saving", function(){

				afterEach( function(){
					branding.save( siteId = variables.site.getId() );
				} );

				it( "stores a logo and shows it back", function(){
					branding.save( siteId = site.getId(), logoUrl = "/media/2026/09/logo-a1b2.png" );

					var html = render( "/admin/settings" );

					// Compared through the same encoder the view uses:
					// `encodeForHTMLAttribute` escapes `/` as `&##x2f;`, so a
					// raw substring search would fail on correct output.
					expect( html ).toInclude( encodeForHTMLAttribute( "/media/2026/09/logo-a1b2.png" ) );
					expect( html ).notToInclude( "No logo set" );
				} );

				it( "turns a saved colour into a custom property the theme can use", function(){
					branding.save( siteId = site.getId(), colorPrimary = "##123456" );

					expect( branding.styleBlockFor( site.getId() ) )
						.toInclude( "--brand-primary: ##123456;" );
				} );

			} );

			/**
			 * Branding changes presentation, so it sits behind
			 * `site.settings.manage` — the same permission as the theme picker.
			 * An editor can write content but cannot restyle the site.
			 */
			it( "is refused to a user whose role does not grant it", function(){
				auth.logout();
				signIn( variables.editor );

				var event = adminRequest(
					uri    = "/admin/settings/branding",
					method = "POST",
					params = { colorPrimary : "##123456" }
				);

				expect( event.getRenderedContent() ).notToInclude( "Branding saved" );
				expect( branding.brandingFor( site.getId() ).colorPrimary ).toBe( "" );
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
		variables.site = sites.createSite( name = "Branding Test", slug = PREFIX & "one" );
		sites.addDomain( site.getId(), "#PREFIX#one.test" );
		roles.seedDefaultRolesForSite( site.getId() );

		variables.owner = users.createUser( site.getId(), "Owner", "owner@brand.test", PASSWORD );
		users.assignRole( owner.getId(), roles.getRoleBySlugForSite( "owner", site.getId() ).getId() );

		variables.editor = users.createUser( site.getId(), "Editor", "editor@brand.test", PASSWORD );
		users.assignRole( editor.getId(), roles.getRoleBySlugForSite( "editor", site.getId() ).getId() );
	}

	private function cleanup(){
		queryExecute( "DELETE FROM sites WHERE slug LIKE :p", { p : PREFIX & "%" } );
	}

}
