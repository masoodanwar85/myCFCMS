/**
 * A site's Google measurement tag.
 *
 * The design decision under test is that the setting holds an **id**, not the
 * script Google publishes. A field holding markup would be arbitrary JavaScript
 * on every page of the site, saved by anyone with settings access; an id can be
 * validated, and the snippet is generated from it.
 *
 * So the specs that matter are the refusals, and the proof that what reaches
 * the page was built here rather than typed by a client.
 *
 * Requires migrations to have run: `box migrate up`.
 */
component extends="coldbox.system.testing.BaseTestCase" appMapping="/app" {

	variables.PREFIX = "zzt-ga-";

	function beforeAll(){
		super.beforeAll();
		variables.analytics = getInstance( "AnalyticsService@core" );
		variables.sites     = getInstance( "SiteService@core" );
		variables.pages     = getInstance( "PageService@pages" );
		variables.themes    = getInstance( "ThemeService@core" );
		variables.settings  = getInstance( "SiteSettingsRepository@core" );
		cleanup();
		seed();
	}

	function afterAll(){
		cleanup();
		super.afterAll();
	}

	function run(){
		describe( "Analytics", function(){

			beforeEach( function(){
				setup();
				analytics.save( site.getId(), "" );
			} );

			describe( "what counts as a tag id", function(){

				it( "accepts a GA4 measurement id", function(){
					analytics.save( site.getId(), "G-K7Z1T7FTBB" );

					expect( analytics.tagIdFor( site.getId() ) ).toBe( "G-K7Z1T7FTBB" );
				} );

				it( "accepts a Tag Manager container id", function(){
					analytics.save( site.getId(), "GTM-ABC1234" );

					expect( analytics.tagIdFor( site.getId() ) ).toBe( "GTM-ABC1234" );
				} );

				it( "upper-cases and trims what was pasted", function(){
					analytics.save( site.getId(), "  g-k7z1t7ftbb  " );

					expect( analytics.tagIdFor( site.getId() ) ).toBe( "G-K7Z1T7FTBB" );
				} );

				/**
				 * The likeliest mistake by far: following Google's instruction
				 * literally and pasting the whole block. Refusing it with an
				 * explanation beats storing markup.
				 */
				it( "refuses the whole script Google shows you", function(){
					expect( function(){
						analytics.save( site.getId(), '<script async src="https://www.googletagmanager.com/gtag/js?id=G-K7Z1T7FTBB"></script>' );
					} ).toThrow( type = "Analytics.InvalidTagId" );
				} );

				it( "refuses anything that is not an id", function(){
					for ( var bad in [ "hello", "G-", "G-abc!", "GTM", "<script>alert(1)</script>", "G-OK'+alert(1)+'" ] ) {
						expect( function(){
							analytics.save( site.getId(), bad );
						} ).toThrow( type = "Analytics.InvalidTagId", message = "", detail = "refused [#bad#]" );
					}
				} );

				/**
				 * Universal Analytics stopped collecting in 2023. Accepting one
				 * silently would leave a site that looks measured and is not.
				 */
				it( "refuses a Universal Analytics id, and says why", function(){
					try {
						analytics.save( site.getId(), "UA-12345678-1" );
						fail( "a UA id was accepted" );
					} catch ( Analytics.InvalidTagId e ) {
						expect( e.message ).toInclude( "2023" );
					}
				} );

				it( "clears the setting when given nothing", function(){
					analytics.save( site.getId(), "G-K7Z1T7FTBB" );
					analytics.save( site.getId(), "" );

					expect( analytics.isConfigured( site.getId() ) ).toBeFalse();
				} );

				/**
				 * A row can reach `site_settings` from a migration, a seed or a
				 * direct UPDATE. The read path re-checks rather than trusting
				 * that whatever wrote it came through `save()`.
				 */
				it( "discards a stored value that would not pass validation today", function(){
					settings.put( site.getId(), analytics.KEY_TAG_ID, "</script><script>alert(1)</script>" );

					expect( analytics.tagIdFor( site.getId() ) ).toBe( "" );
				} );

			} );

			describe( "what it renders", function(){

				it( "renders nothing at all when no tag is set", function(){
					var built = analytics.analyticsFor( site.getId() );

					expect( built.head ).toBe( "" );
					expect( built.body ).toBe( "" );
					expect( built.kind ).toBe( "" );
				} );

				it( "writes the gtag snippet for a G- id", function(){
					analytics.save( site.getId(), "G-K7Z1T7FTBB" );

					var built = analytics.analyticsFor( site.getId() );

					expect( built.kind ).toBe( "gtag" );
					expect( built.head ).toInclude( "gtag/js?id=G-K7Z1T7FTBB" );
					expect( built.head ).toInclude( "gtag('config','G-K7Z1T7FTBB')" );
					// gtag has no noscript half.
					expect( built.body ).toBe( "" );
				} );

				it( "writes the container snippet and its noscript for a GTM- id", function(){
					analytics.save( site.getId(), "GTM-ABC1234" );

					var built = analytics.analyticsFor( site.getId() );

					expect( built.kind ).toBe( "gtm" );
					expect( built.head ).toInclude( "gtm.js?id=" );
					expect( built.body ).toInclude( "ns.html?id=GTM-ABC1234" );
					expect( built.body ).toInclude( "noscript" );
				} );

			} );

			describe( "what the site serves", function(){

				it( "puts no script on the page when nothing is configured", function(){
					expect( render() ).notToInclude( "googletagmanager" );
				} );

				it( "puts the tag in the head when one is configured", function(){
					analytics.save( site.getId(), "G-K7Z1T7FTBB" );

					var html = render();

					expect( html ).toInclude( "G-K7Z1T7FTBB" );
					// Before the head closes, which is what Google asks for.
					expect( find( "googletagmanager", html ) ).toBeLT( find( "</head>", html ) );
				} );

				it( "puts the Tag Manager fallback after the body opens", function(){
					analytics.save( site.getId(), "GTM-ABC1234" );

					var html = render();

					expect( html ).toInclude( "ns.html?id=GTM-ABC1234" );
					expect( find( "ns.html", html ) ).toBeGT( find( "<body", html ) );
				} );

			} );

		} );
	}

	/* --------------------------------------------------------------------- */

	private string function render(){
		setup();

		var event = this.get( route = "/zzt-ga-page", headers = { "Host" : "#PREFIX#one.test" } );

		return event.getRenderedContent() & ( event.getHandlerResults() ?: "" );
	}

	private function seed(){
		variables.site = sites.createSite( name = "Analytics Test", slug = PREFIX & "one" );
		sites.addDomain( site.getId(), "#PREFIX#one.test", true );
		themes.setThemeForSite( site.getId(), "default" );

		var page = pages.createPage(
			siteId  = site.getId(),
			title   = "Analytics Page",
			slug    = "zzt-ga-page",
			content = "<p>hello</p>",
			status  = "published"
		);

		pages.publishPage( page.getId() );
	}

	private function cleanup(){
		queryExecute( "DELETE FROM sites WHERE slug LIKE :p", { p : PREFIX & "%" } );
	}

}
