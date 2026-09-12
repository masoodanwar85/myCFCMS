/**
 * A first-visit notice, through a real routed request.
 *
 * The design decision under test is that the setting holds copy, not markup,
 * and that nothing reaches the page when the notice is off or expired.
 *
 * Requires migrations to have run: `box migrate up`.
 */
component extends="coldbox.system.testing.BaseTestCase" appMapping="/app" {

	variables.PREFIX = "zzt-nt-";

	function beforeAll(){
		super.beforeAll();
		variables.notice   = getInstance( "SiteNoticeService@core" );
		variables.sites    = getInstance( "SiteService@core" );
		variables.pages    = getInstance( "PageService@pages" );
		variables.themes   = getInstance( "ThemeService@core" );
		cleanup();
		seed();
	}

	function afterAll(){
		cleanup();
		super.afterAll();
	}

	function run(){
		describe( "the first-visit notice", function(){

			beforeEach( function(){
				setup();
				notice.save( siteId = site.getId() );
			} );

			it( "puts no dialog on the page when nothing is configured", function(){
				expect( render() ).notToInclude( "cms-site-notice" );
			} );

			it( "puts the dialog on the page when one is configured", function(){
				notice.save(
					siteId    = site.getId(),
					enabled   = true,
					heading   = "Special:",
					body      = "Use our Will Creation Tool and create a Will at a reduced rate.",
					ctaUrl    = "/will",
					ctaLabel  = "Create your Will",
					expiresAt = dateFormat( dateAdd( "d", 30, now() ), "yyyy-mm-dd" )
				);

				var html = render();

				expect( html ).toInclude( "cms-site-notice" );
				expect( html ).toInclude( encodeForHTML( "Special:" ) );
				expect( html ).toInclude( "Will Creation Tool" );
				expect( html ).toInclude( encodeForHTMLAttribute( "/will" ) );
				expect( html ).toInclude( "Create your Will" );
			} );

			it( "encodes copy rather than emitting it as markup", function(){
				notice.save(
					siteId  = site.getId(),
					enabled = true,
					heading = "<script>alert(1)</script>",
					body    = "Offer <b>now</b>."
				);

				var html = render();

				expect( html ).notToInclude( "<script>alert(1)</script>" );
				expect( html ).toInclude( encodeForHTML( "<script>alert(1)</script>" ) );
				expect( html ).toInclude( encodeForHTML( "Offer <b>now</b>." ) );
			} );

			it( "puts no dialog on the page once the end date has passed", function(){
				notice.save(
					siteId    = site.getId(),
					enabled   = true,
					heading   = "Special:",
					body      = "Expired offer.",
					expiresAt = "2020-01-01"
				);

				expect( render() ).notToInclude( "cms-site-notice" );
			} );

			it( "still appears on a themed 404, which is this site's chrome", function(){
				notice.save(
					siteId  = site.getId(),
					enabled = true,
					heading = "Special:",
					body    = "Use our Will Creation Tool."
				);

				setup();

				var event = this.get(
					route   = "/no-such-page-zzt-nt",
					headers = { "Host" : "#PREFIX#one.test" }
				);
				var html  = event.getRenderedContent() & ( event.getHandlerResults() ?: "" );

				expect( html ).toInclude( "cms-site-notice" );
			} );

		} );
	}

	/* --------------------------------------------------------------------- */

	private string function render(){
		setup();

		var event = this.get( route = "/zzt-nt-page", headers = { "Host" : "#PREFIX#one.test" } );

		return event.getRenderedContent() & ( event.getHandlerResults() ?: "" );
	}

	private function seed(){
		variables.site = sites.createSite( name = "Notice Test", slug = PREFIX & "one" );
		sites.addDomain( site.getId(), "#PREFIX#one.test", true );
		themes.setThemeForSite( site.getId(), "default" );

		var page = pages.createPage(
			siteId  = site.getId(),
			title   = "Notice Page",
			slug    = "zzt-nt-page",
			content = "<p>hello</p>",
			status  = "published"
		);

		pages.publishPage( page.getId() );
	}

	private function cleanup(){
		queryExecute( "DELETE FROM sites WHERE slug LIKE :p", { p : PREFIX & "%" } );
	}

}
