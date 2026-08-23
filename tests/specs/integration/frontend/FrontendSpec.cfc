/**
 * The whole public request pipeline, end to end:
 *
 *   Host header -> TenantInterceptor -> route -> Frontend -> resolver -> theme -> HTML
 *
 * Requests go through ColdBox's router with a mocked `Host` header, so this
 * exercises the real route, the real interceptor and the real themes on disk
 * rather than any of them in isolation.
 *
 * Requires migrations to have run: `box migrate up`.
 */
component extends="coldbox.system.testing.BaseTestCase" appMapping="/app" {

	variables.PREFIX = "zzt-fe-";

	function beforeAll(){
		super.beforeAll();
		variables.sites  = getInstance( "SiteService@core" );
		variables.pages  = getInstance( "PageService@pages" );
		variables.themes = getInstance( "ThemeService@core" );
		cleanup();
		seed();
	}

	function afterAll(){
		cleanup();
		super.afterAll();
	}

	function run(){
		describe( "Public site rendering", function(){

			beforeEach( function( currentSpec ){
				setup();
			} );

			describe( "a resolved tenant", function(){

				it( "serves the home page at the site root", function(){
					var html = render( "/", "#PREFIX#one.test" );

					expect( html ).toInclude( "Welcome to Client One" );
					expect( html ).toInclude( "<title>Home</title>" );
				} );

				it( "serves a top-level page", function(){
					expect( render( "/about", "#PREFIX#one.test" ) ).toInclude( "About Client One" );
				} );

				it( "serves a nested page by its full path", function(){
					var html = render( "/about/team", "#PREFIX#one.test" );

					expect( html ).toInclude( "Our people" );
					expect( html ).toInclude( "<title>Team</title>" );
				} );

				it( "renders the site's navigation", function(){
					var html = render( "/about", "#PREFIX#one.test" );

					expect( html ).toInclude( 'href="/about"' );
				} );

				it( "renders a breadcrumb for a nested page", function(){
					var html = render( "/about/team", "#PREFIX#one.test" );

					expect( html ).toInclude( "crumbs" );
				} );

				it( "uses the page's meta description", function(){
					var html = render( "/about", "#PREFIX#one.test" );

					expect( html ).toInclude( "Everything about Client One" );
				} );

			} );

			describe( "tenant isolation", function(){

				it( "serves each domain its own site", function(){
					expect( render( "/about", "#PREFIX#one.test" ) ).toInclude( "About Client One" );
					expect( render( "/about", "#PREFIX#two.test" ) ).toInclude( "About Client Two" );
				} );

				it( "does not serve one site's page on another's domain", function(){
					expect( render( "/only-on-one", "#PREFIX#one.test" ) ).toInclude( "Unique to one" );

					var other = render( "/only-on-one", "#PREFIX#two.test" );
					expect( other ).notToInclude( "Unique to one" );
					expect( other ).toInclude( "Not found" );
				} );

			} );

			describe( "themes", function(){

				it( "renders each site through its own theme", function(){
					expect( render( "/about", "#PREFIX#one.test" ) ).toInclude( "Default</strong> theme" );

					var two = render( "/about", "#PREFIX#two.test" );
					expect( two ).toInclude( 'data-theme="starter"' );
					expect( two ).toInclude( 'data-view="starter-page"' );
				} );

				it( "renders a site's 404 in that site's theme", function(){
					expect( render( "/nowhere", "#PREFIX#one.test" ) ).toInclude( "Page not found" );
					expect( render( "/nowhere", "#PREFIX#two.test" ) ).toInclude( 'data-view="starter-404"' );
				} );

			} );

			describe( "unpublished content", function(){

				it( "does not serve a draft page", function(){
					var html = render( "/secret", "#PREFIX#one.test" );

					expect( html ).notToInclude( "Draft only" );
					expect( html ).toInclude( "Page not found" );
				} );

				it( "keeps a draft page out of the navigation", function(){
					expect( render( "/about", "#PREFIX#one.test" ) ).notToInclude( ">Secret<" );
				} );

				it( "serves nothing at the root when the home page is a draft", function(){
					var html = render( "/", "#PREFIX#three.test" );

					expect( html ).toInclude( "Page not found" );
				} );

			} );

			describe( "an unresolved domain", function(){

				it( "shows Core's own page, since there is no theme to use", function(){
					var html = render( "/", "#PREFIX#nobody.test" );

					expect( html ).toInclude( "No site is configured for this address" );
				} );

				it( "does the same for any path on that domain", function(){
					expect( render( "/about", "#PREFIX#nobody.test" ) ).toInclude( "No site is configured" );
				} );

				it( "does not leak any tenant's content", function(){
					var html = render( "/about", "#PREFIX#nobody.test" );

					expect( html ).notToInclude( "About Client One" );
					expect( html ).notToInclude( "About Client Two" );
				} );

				it( "will not serve a site whose domain has been deactivated", function(){
					var domains = sites.getDomains( variables.siteOne.getId() );
					var target  = domains.filter( ( d ) => d.getDomain() == "#PREFIX#one.test" )[ 1 ];

					getInstance( "SiteDomainRepository@core" ).setActive( target.getId(), false );

					try {
						expect( render( "/about", "#PREFIX#one.test" ) ).toInclude( "No site is configured" );
					} finally {
						getInstance( "SiteDomainRepository@core" ).setActive( target.getId(), true );
					}
				} );

				it( "will not serve an inactive site", function(){
					getInstance( "SiteRepository@core" ).update( variables.siteTwo.setStatus( "inactive" ) );

					try {
						expect( render( "/about", "#PREFIX#two.test" ) ).toInclude( "No site is configured" );
					} finally {
						getInstance( "SiteRepository@core" ).update( variables.siteTwo.setStatus( "active" ) );
					}
				} );

			} );

			describe( "path handling", function(){

				it( "treats trailing slashes and casing as the same URL", function(){
					for ( var candidate in [ "/about/team", "/about/team/", "/About/Team" ] ) {
						expect( render( candidate, "#PREFIX#one.test" ) ).toInclude( "Our people" );
					}
				} );

				it( "resolves a domain sent with a port", function(){
					expect( render( "/about", "#PREFIX#one.test:8080" ) ).toInclude( "About Client One" );
				} );

			} );

		} );
	}

	/**
	 * Issue a routed GET with a mocked Host header, and return the HTML.
	 */
	private string function render( required string route, required string host ){
		setup();

		var event = this.get( route = arguments.route, headers = { "Host" : arguments.host } );

		return event.getRenderedContent() & ( event.getHandlerResults() ?: "" );
	}

	private function seed(){
		variables.siteOne = newSite( "Client One", "one" );
		variables.siteTwo = newSite( "Client Two", "two" );

		themes.setThemeForSite( siteOne.getId(), "default" );
		themes.setThemeForSite( siteTwo.getId(), "starter" );

		buildPages( siteOne, "Client One" );
		buildPages( siteTwo, "Client Two" );

		var unique = pages.createPage(
			siteId  = siteOne.getId(),
			title   = "Only On One",
			content = "<p>Unique to one.</p>"
		);
		pages.publishPage( unique.getId() );

		// A third site whose home page is deliberately left unpublished.
		variables.siteThree = newSite( "Client Three", "three" );
		var draftHome = pages.createPage( siteId = siteThree.getId(), title = "Home" );
		pages.setHomePage( siteThree.getId(), draftHome.getId() );
	}

	private function buildPages( required any site, required string label ){
		var home = pages.createPage(
			siteId  = arguments.site.getId(),
			title   = "Home",
			content = "<p>Welcome to #arguments.label#.</p>"
		);
		pages.publishPage( home.getId() );
		pages.setHomePage( arguments.site.getId(), home.getId() );

		var about = pages.createPage(
			siteId          = arguments.site.getId(),
			title           = "About",
			content         = "<p>About #arguments.label#.</p>",
			metaDescription = "Everything about #arguments.label#."
		);
		pages.publishPage( about.getId() );

		var team = pages.createPage(
			siteId   = arguments.site.getId(),
			title    = "Team",
			parentId = about.getId(),
			content  = "<p>Our people.</p>"
		);
		pages.publishPage( team.getId() );

		// Left as a draft on purpose.
		pages.createPage(
			siteId  = arguments.site.getId(),
			title   = "Secret",
			content = "<p>Draft only.</p>"
		);
	}

	private function newSite( required string name, required string handle ){
		var site = sites.createSite( name = arguments.name, slug = PREFIX & arguments.handle );
		sites.addDomain( site.getId(), "#PREFIX##arguments.handle#.test" );
		return site;
	}

	private function cleanup(){
		queryExecute( "DELETE FROM sites WHERE slug LIKE :prefix", { prefix : PREFIX & "%" } );
	}

}
