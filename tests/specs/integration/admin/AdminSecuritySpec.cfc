/**
 * The admin request boundary, driven through real routed requests.
 *
 * The single most important assertion here is that a refused request does not
 * merely return a 403 — it must not render the protected screen's content.
 * ColdBox invokes an action after `preHandler` regardless of
 * `event.noExecution()`, so an earlier version of this boundary returned a 403
 * whose body was the very page the user was not allowed to see. These specs
 * exist so that cannot come back.
 *
 * Requires migrations to have run: `box migrate up`.
 */
component extends="coldbox.system.testing.BaseTestCase" appMapping="/app" {

	variables.PREFIX   = "zzt-as-";
	variables.PASSWORD = "correct-horse-battery";

	function beforeAll(){
		super.beforeAll();
		variables.sites = getInstance( "SiteService@core" );
		variables.roles = getInstance( "RoleService@core" );
		variables.users = getInstance( "UserService@core" );
		variables.pages = getInstance( "PageService@pages" );
		variables.auth  = getInstance( "AuthenticationService@core" );
		variables.csrf  = getInstance( "CsrfService@core" );
		cleanup();
		seed();
	}

	function afterAll(){
		auth.logout();
		cleanup();
		super.afterAll();
	}

	function run(){
		describe( "Admin security", function(){

			beforeEach( function(){
				setup();
				auth.logout();
			} );

			afterEach( function(){
				auth.logout();
			} );

			describe( "before signing in", function(){

				it( "sends an anonymous visitor to the sign-in screen", function(){
					var event = adminRequest( "/admin" );

					expect( event.getValue( "relocate_URI", "" ) ).toInclude( "/admin/login" );
				} );

				it( "guards every admin screen, not just the dashboard", function(){
					for ( var uri in [ "/admin/users", "/admin/roles", "/admin/settings", "/admin/pages" ] ) {
						var event = adminRequest( uri );
						expect( event.getValue( "relocate_URI", "" ) ).toInclude( "/admin/login" );
					}
				} );

				it( "shows the sign-in screen itself without a session", function(){
					var html = render( "/admin/login" );

					expect( html ).toInclude( "Sign in" );
					expect( html ).toInclude( "csrfToken" );
				} );

			} );

			describe( "permissions", function(){

				it( "lets an owner reach a screen their role grants", function(){
					signIn( variables.owner );

					expect( render( "/admin/pages" ) ).toInclude( "The content tree" );
				} );

				it( "refuses a screen the user's roles do not grant", function(){
					signIn( variables.editor );

					var html = render( "/admin/pages" );

					expect( html ).toInclude( "Not allowed" );
					expect( html ).toInclude( "pages.view" );
				} );

				it( "does NOT render the protected content when refusing", function(){
					signIn( variables.editor );

					var html = render( "/admin/pages" );

					// The refused screen's own content must be absent entirely.
					expect( html ).notToInclude( "The content tree" );
					expect( html ).notToInclude( "zzt-as-secret-page" );
				} );

				it( "refuses a create screen to someone with only view rights", function(){
					signIn( variables.editor );

					expect( render( "/admin/roles/new" ) ).toInclude( "Not allowed" );
				} );

				it( "lets the same user reach screens they do have rights for", function(){
					signIn( variables.editor );

					expect( render( "/admin/users" ) ).toInclude( "People who can sign in" );
				} );

				it( "gives a super admin every screen", function(){
					signIn( variables.root );

					expect( render( "/admin/pages" ) ).toInclude( "The content tree" );
					expect( render( "/admin/roles" ) ).toInclude( "What each group" );
				} );

			} );

			describe( "navigation", function(){

				it( "only lists sections the user may reach", function(){
					signIn( variables.editor );

					var html = render( "/admin" );

					expect( html ).toInclude( ">Users<" );
					expect( html ).notToInclude( ">Pages<" );
				} );

				it( "lists the Pages section for someone who may see it", function(){
					signIn( variables.owner );

					expect( render( "/admin" ) ).toInclude( ">Pages<" );
				} );

			} );

			describe( "the enquiries toolbar", function(){

				/**
				 * The filter links and the "Forms" link sit in one row. Before
				 * this, "Forms" carried the solid button style and so read as
				 * the selected filter no matter which filter was actually on.
				 */
				it( "marks the filter the URL is actually showing", function(){
					signIn( variables.owner );

					var all = render( "/admin/contact" );

					expect( all ).toInclude( 'class="btn secondary is-current" href="/admin/contact"' );
					expect( all ).notToInclude( 'is-current" href="/admin/contact?status=new"' );

					var unread = render( "/admin/contact", "GET", { "status" : "new" } );

					expect( unread ).toInclude( 'class="btn secondary is-current" href="/admin/contact?status=new"' );
					expect( unread ).notToInclude( 'class="btn secondary is-current" href="/admin/contact"' );
				} );

				it( "never marks the Forms link as a filter", function(){
					signIn( variables.owner );

					expect( render( "/admin/contact" ) )
						.notToInclude( 'is-current" href="/admin/contact/forms"' );
				} );

			} );

			describe( "CSRF", function(){

				it( "refuses a state-changing request with no token", function(){
					signIn( variables.owner );

					var html = render( "/admin/pages/publish/#variables.draftPage.getId()#", "POST", {} );

					expect( html ).toInclude( "expired" );
				} );

				it( "refuses a wrong token", function(){
					signIn( variables.owner );

					var html = render(
						"/admin/pages/publish/#variables.draftPage.getId()#",
						"POST",
						{ csrfToken : "not-the-real-token" }
					);

					expect( html ).toInclude( "expired" );
				} );

				it( "leaves the data untouched when it refuses", function(){
					signIn( variables.owner );

					render( "/admin/pages/publish/#variables.draftPage.getId()#", "POST", {} );

					expect( pages.getPageById( variables.draftPage.getId() ).isPublished() ).toBeFalse();
				} );

				it( "accepts the session's own token", function(){
					signIn( variables.owner );

					render(
						"/admin/pages/publish/#variables.draftPage.getId()#",
						"POST",
						{ csrfToken : csrf.getCurrentToken() }
					);

					expect( pages.getPageById( variables.draftPage.getId() ).isPublished() ).toBeTrue();

					pages.unpublishPage( variables.draftPage.getId() );
				} );

				it( "does not demand a token for a plain GET", function(){
					signIn( variables.owner );

					expect( render( "/admin/pages" ) ).toInclude( "The content tree" );
				} );

			} );

			describe( "without a tenant", function(){

				it( "does not expose the admin on an unresolved domain", function(){
					var html = render( "/admin", "GET", {}, "#PREFIX#nobody.test" );

					expect( html ).toInclude( "No site is configured" );
					expect( html ).notToInclude( "Sign in" );
				} );

			} );

		} );
	}

	/* --------------------------------------------------------------------- */

	/**
	 * Named `adminRequest` rather than `request`: BaseTestCase already has a
	 * `request()` and a same-named private method shadows it.
	 */
	private function adminRequest(
		required string uri,
		string method = "GET",
		struct params = {},
		string host   = ""
	){
		setup();

		return this.request(
			route   = arguments.uri,
			params  = arguments.params,
			headers = { "Host" : len( arguments.host ) ? arguments.host : "#PREFIX#one.test" },
			method  = arguments.method
		);
	}

	private string function render(
		required string uri,
		string method = "GET",
		struct params = {},
		string host   = ""
	){
		var event = adminRequest( argumentCollection = arguments );

		return event.getRenderedContent() & ( event.getHandlerResults() ?: "" );
	}

	/**
	 * Establish a session directly, so a spec about authorisation does not have
	 * to go through the sign-in form first.
	 */
	private function signIn( required any user ){
		getInstance( "TenantContext@core" ).setCurrentTenant( variables.site );
		auth.startSessionFor( arguments.user, variables.site.getId() );

		return this;
	}

	private function seed(){
		variables.site = sites.createSite( name = "Admin Sec", slug = PREFIX & "one" );
		sites.addDomain( site.getId(), "#PREFIX#one.test" );
		roles.seedDefaultRolesForSite( site.getId() );

		variables.owner = users.createUser( site.getId(), "Owner", "owner@sec.test", PASSWORD );
		users.assignRole( owner.getId(), roles.getRoleBySlugForSite( "owner", site.getId() ).getId() );

		variables.editor = users.createUser( site.getId(), "Editor", "editor@sec.test", PASSWORD );
		users.assignRole( editor.getId(), roles.getRoleBySlugForSite( "editor", site.getId() ).getId() );

		variables.root = users.createSuperAdmin( "Root", "#PREFIX#root@platform.test", PASSWORD );

		variables.draftPage = pages.createPage(
			siteId = site.getId(),
			title  = "zzt-as-secret-page",
			slug   = "zzt-as-secret-page"
		);
	}

	private function cleanup(){
		queryExecute( "DELETE FROM sites WHERE slug LIKE :p", { p : PREFIX & "%" } );
		queryExecute( "DELETE FROM users WHERE site_id IS NULL AND email LIKE :p", { p : PREFIX & "%" } );
	}

}
