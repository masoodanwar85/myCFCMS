/**
 * The SEO report screen, through a real routed request.
 *
 * The handler and service are covered elsewhere; these render the view, because
 * a template error there reaches production unseen — the handler compiles, the
 * tests pass, and the screen 500s.
 *
 * Requires migrations to have run: `box migrate up`.
 */
component extends="coldbox.system.testing.BaseTestCase" appMapping="/app" {

	variables.PREFIX   = "zzt-seoui-";
	variables.PASSWORD = "correct-horse-battery";

	function beforeAll(){
		super.beforeAll();

		variables.sites  = getInstance( "SiteService@core" );
		variables.roles  = getInstance( "RoleService@core" );
		variables.users  = getInstance( "UserService@core" );
		variables.auth   = getInstance( "AuthenticationService@core" );
		variables.repo   = getInstance( "SeoAuditRepository@seoaudit" );

		cleanup();
		seed();
	}

	function afterAll(){
		auth.logout();
		cleanup();
		super.afterAll();
	}

	function run(){
		describe( "The SEO screen", function(){

			beforeEach( function(){
				setup();
				auth.logout();
				signIn( variables.owner );
			} );

			afterEach( function(){
				auth.logout();
			} );

			it( "says so plainly when nothing has been run", function(){
				// Rendered before any audit exists, which is the state every
				// site is in the first time somebody opens this.
				var html = render( "/admin/seo" );

				expect( html ).toInclude( "No audit has been run" );
			} );

			describe( "with a stored report", function(){

				beforeEach( function(){
					variables.audit = storeReport();
				} );

				afterEach( function(){
					repo.deleteAudit( variables.audit.getId(), site.getId() );
				} );

				it( "renders the report with its counts and both groupings", function(){
					var html = render( "/admin/seo" );

					expect( html ).toInclude( "errors" );
					expect( html ).toInclude( "By problem" );
					expect( html ).toInclude( "By page" );
					expect( html ).toInclude( "History" );
				} );

				it( "shows each finding's message and offending value", function(){
					var html = render( "/admin/seo" );

					expect( html ).toInclude( "has no title" );
					expect( html ).toInclude( "two h1 headings" );
					// The detail is what makes a finding actionable without
					// opening the page.
					expect( html ).toInclude( "Theme heading" );
				} );

				it( "names severities in words, not only in colour", function(){
					// A list someone is being asked to prioritise cannot encode
					// priority in hue alone.
					var html = render( "/admin/seo" );

					expect( html ).toInclude( ">error<" );
					expect( html ).toInclude( ">warning<" );
				} );

				it( "offers an edit link for a finding that is on a page", function(){
					var html = render( "/admin/seo" );

					expect( html ).toInclude( "/admin/pages/edit/" & variables.page.getId() );
				} );

				it( "opens an older report by id", function(){
					var html = render( "/admin/seo/show/" & variables.audit.getId() );

					expect( html ).toInclude( "By problem" );
				} );

				it( "refuses an audit id belonging to another site", function(){
					var other = sites.createSite( name = "Other", slug = PREFIX & "two" );
					var theirs = repo.createAudit(
						getInstance( "SeoAudit@seoaudit" ).setSiteId( other.getId() ).setStatus( "finished" )
					);

					var html = render( "/admin/seo/show/" & theirs.getId() );

					expect( html ).notToInclude( "By problem" );
				} );

			} );

			it( "hides the run button from a user who may only view", function(){
				// Reading last night's report is free; starting a run fetches
				// every public URL of the site.
				auth.logout();
				signIn( variables.viewer );

				var html = render( "/admin/seo" );

				expect( html ).notToInclude( "Run audit" );
			} );

		} );
	}

	/* --------------------------------------------------------------------- */

	private function storeReport(){
		var audit = repo.createAudit(
			getInstance( "SeoAudit@seoaudit" ).setSiteId( site.getId() ).setStatus( "running" )
		);

		repo.addIssues( audit.getId(), site.getId(), [
			{
				"path" : "", "checkId" : "title.missing", "severity" : "error",
				"message" : "This page has no title.", "detail" : ""
			},
			{
				"path" : "about", "pageId" : variables.page.getId(),
				"checkId" : "heading.multipleH1", "severity" : "error",
				"message" : "This page has two h1 headings.", "detail" : "Theme heading | Author heading"
			},
			{
				"path" : "about", "pageId" : variables.page.getId(),
				"checkId" : "description.missing", "severity" : "warning",
				"message" : "No meta description.", "detail" : ""
			}
		] );

		audit
			.setStatus( "finished" )
			.setUrlCount( 2 )
			.setErrorCount( 2 )
			.setWarningCount( 1 )
			.setNoticeCount( 0 );

		return repo.finishAudit( audit );
	}

	private function adminRequest( required string uri, string method = "GET", struct params = {} ){
		setup();

		var sent = duplicate( arguments.params );

		if ( arguments.method == "POST" && !structKeyExists( sent, "csrfToken" ) ) {
			sent.csrfToken = getInstance( "CsrfService@core" ).getCurrentToken();
		}

		return this.request(
			route   = arguments.uri,
			params  = sent,
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
		variables.site = sites.createSite( name = "SEO Screen", slug = PREFIX & "one" );
		sites.addDomain( site.getId(), "#PREFIX#one.test", true );
		roles.seedDefaultRolesForSite( site.getId() );

		variables.owner = users.createUser( site.getId(), "Owner", "owner@seoui.test", PASSWORD );
		users.assignRole( owner.getId(), roles.getRoleBySlugForSite( "owner", site.getId() ).getId() );

		variables.viewer = users.createUser( site.getId(), "Editor", "editor@seoui.test", PASSWORD );
		users.assignRole( viewer.getId(), roles.getRoleBySlugForSite( "editor", site.getId() ).getId() );

		variables.page = getInstance( "PageService@pages" ).createPage(
			siteId = site.getId(),
			title  = "About",
			slug   = "about",
			content = "<p>x</p>"
		);
	}

	private function cleanup(){
		queryExecute( "DELETE FROM sites WHERE slug LIKE :p", { p : PREFIX & "%" } );
	}

}
