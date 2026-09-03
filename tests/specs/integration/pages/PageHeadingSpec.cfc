/**
 * The per-page "show the title as a heading" switch.
 *
 * Two things are worth guarding, and they pull in opposite directions.
 *
 * The switch has to actually turn OFF — a boolean that only ever goes one way
 * is this codebase's most repeated bug, because `?:` and truthiness checks both
 * treat `false` as absent. Every layer here is checked with the value set to
 * false, not just to true.
 *
 * And turning it off must change *only* the on-page heading. The title is also
 * the browser tab, the menu label, the breadcrumb and the `<title>` tag; a
 * switch that quietly took those away would look like it worked and would be
 * found much later.
 *
 * Requires migrations to have run: `box migrate up`.
 */
component extends="coldbox.system.testing.BaseTestCase" appMapping="/app" {

	variables.PREFIX = "zzt-head-";

	function beforeAll(){
		super.beforeAll();
		variables.pages    = getInstance( "PageService@pages" );
		variables.sites    = getInstance( "SiteService@core" );
		variables.themes   = getInstance( "ThemeService@core" );
		variables.settings = getInstance( "SiteSettingsRepository@core" );
		cleanup();
		seed();
	}

	function afterAll(){
		getInstance( "AuthenticationService@core" ).logout();
		cleanup();
		super.afterAll();
	}

	function run(){
		describe( "Showing a page's title as a heading", function(){

			describe( "the field itself", function(){

				it( "is on for a page created without mentioning it", function(){
					var page = newPage();

					expect( page.getShowHeading() ).toBeTrue();
				} );

				it( "can be turned off, and stays off across a reload", function(){
					var page = newPage( { showHeading : false } );

					expect( page.getShowHeading() ).toBeFalse();
					expect( pages.getPageById( page.getId() ).getShowHeading() ).toBeFalse();
				} );

				it( "can be turned back on", function(){
					var page = newPage( { showHeading : false } );

					pages.updatePage(
						pageId = page.getId(),
						title  = page.getTitle(),
						seo    = { showHeading : true }
					);

					expect( pages.getPageById( page.getId() ).getShowHeading() ).toBeTrue();
				} );

				/**
				 * An update that says nothing about the switch must not reset
				 * it — otherwise editing a page's content from any other form
				 * silently turns the heading back on.
				 */
				it( "is left alone by an update that does not mention it", function(){
					var page = newPage( { showHeading : false } );

					pages.updatePage(
						pageId  = page.getId(),
						title   = page.getTitle(),
						content = "<p>Edited elsewhere.</p>"
					);

					expect( pages.getPageById( page.getId() ).getShowHeading() ).toBeFalse();
				} );

			} );

			describe( "what the site renders", function(){

				it( "prints the heading by default", function(){
					var page = publishedPage( "Heading Shown", true );

					expect( render( page ) ).toInclude( "<h1>Heading Shown</h1>" );
				} );

				it( "leaves the heading out when the switch is off", function(){
					var page = publishedPage( "Heading Hidden", false );

					expect( render( page ) ).notToInclude( "<h1>Heading Hidden</h1>" );
				} );

				it( "still renders the page's content", function(){
					var page = publishedPage( "Content Kept", false );

					expect( render( page ) ).toInclude( "the body is still here" );
				} );

				/**
				 * The part that would be easy to break: this is a display
				 * switch, not a way to have a page with no title.
				 */
				it( "keeps the title in the document title", function(){
					var page = publishedPage( "Tab Title Kept", false );

					expect( render( page ) ).toInclude( "<title>Tab Title Kept" );
				} );

			} );

			describe( "the editor", function(){

				it( "ticks the box for a new page, because that is the default", function(){
					expect( adminForm() ).toMatch( 'name="showHeading"[^>]*checked' );
				} );

				it( "carries the marker that lets an unticked box mean false", function(){
					expect( adminForm() ).toInclude( 'name="contentTabPresent"' );
				} );

				/**
				 * An author who hides the theme's heading has to be able to
				 * write their own. The sanitiser has always allowed `h1`; the
				 * editor's style menu was what withheld it, which made the
				 * hide-the-heading option a dead end.
				 */
				it( "offers a Page heading style, so the author can write their own h1", function(){
					var html = adminForm();

					expect( html ).toInclude( "Page heading" );
					expect( html ).toMatch( 'model:\s*"heading1"' );
				} );

			} );

			describe( "an author-written heading", function(){

				it( "survives sanitising", function(){
					var page = pages.createPage(
						siteId  = site.getId(),
						title   = "Own Heading " & createUUID(),
						content = "<h1>Written by the author</h1><p>Body.</p>",
						seo     = { showHeading : false }
					);

					expect( pages.getPageById( page.getId() ).getContent() )
						.toInclude( "<h1>Written by the author</h1>" );
				} );

				it( "reaches the page unchanged, with no heading from the theme", function(){
					var page = pages.createPage(
						siteId  = site.getId(),
						title   = "Theme Heading Off",
						slug    = "zzt-own-heading",
						content = "<h1>My own headline</h1><p>the body is still here</p>",
						status  = "published",
						seo     = { showHeading : false }
					);

					pages.publishPage( page.getId() );

					var html = render( page );

					expect( html ).toInclude( "<h1>My own headline</h1>" );
					expect( html ).notToInclude( "<h1>Theme Heading Off</h1>" );
				} );

				/**
				 * The trap the two options create together: the theme's
				 * heading on *and* an h1 in the content is two top-level
				 * headings, which nothing else would report.
				 */
				it( "is flagged in the editor when it would duplicate the theme's", function(){
					var page = pages.createPage(
						siteId  = site.getId(),
						title   = "Duplicate Heading",
						slug    = "zzt-duplicate-heading",
						content = "<h1>Also a headline</h1>",
						seo     = { showHeading : true }
					);

					expect( adminForm( page.getId() ) ).toInclude( "two top-level headings" );
				} );

				it( "is not flagged when the theme's heading is off", function(){
					var page = pages.createPage(
						siteId  = site.getId(),
						title   = "No Duplicate",
						slug    = "zzt-no-duplicate",
						content = "<h1>The only headline</h1>",
						seo     = { showHeading : false }
					);

					expect( adminForm( page.getId() ) ).notToInclude( "two top-level headings" );
				} );

			} );

		} );
	}

	/* --------------------------------------------------------------------- */

	private function newPage( struct seo = {} ){
		return pages.createPage(
			siteId = site.getId(),
			title  = "Spec " & createUUID(),
			seo    = arguments.seo
		);
	}

	private function publishedPage( required string title, required boolean showHeading ){
		var page = pages.createPage(
			siteId  = site.getId(),
			title   = arguments.title,
			slug    = "zzt-" & lCase( replace( arguments.title, " ", "-", "all" ) ),
			content = "<p>the body is still here</p>",
			status  = "published",
			seo     = { showHeading : arguments.showHeading }
		);

		pages.publishPage( page.getId() );

		return page;
	}

	private string function render( required any page ){
		setup();

		var event = this.get(
			route   = "/" & arguments.page.getPath(),
			headers = { "Host" : "#PREFIX#one.test" }
		);

		return event.getRenderedContent() & ( event.getHandlerResults() ?: "" );
	}

	/**
	 * The new-page form, through a real signed-in request.
	 *
	 * Rendered the long way round rather than by calling the renderer on the
	 * view directly: the template reads `prc.page`, `prc.csrfToken` and the
	 * parent list, so a bare render tests only how well the spec can fake a
	 * request collection.
	 */
	private string function adminForm( numeric pageId = 0 ){
		setup();

		getInstance( "TenantContext@core" ).setCurrentTenant( variables.site );
		getInstance( "AuthenticationService@core" ).startSessionFor( variables.owner, site.getId() );

		var event = this.get(
			route   = arguments.pageId ? "/admin/pages/edit/#arguments.pageId#" : "/admin/pages/new",
			headers = { "Host" : "#PREFIX#one.test" }
		);

		return event.getRenderedContent() & ( event.getHandlerResults() ?: "" );
	}

	private function seed(){
		variables.site = sites.createSite( name = "Heading Test", slug = PREFIX & "one" );
		sites.addDomain( site.getId(), "#PREFIX#one.test", true );
		themes.setThemeForSite( site.getId(), "default" );

		var roles = getInstance( "RoleService@core" );
		var users = getInstance( "UserService@core" );

		roles.seedDefaultRolesForSite( site.getId() );
		variables.owner = users.createUser( site.getId(), "Owner", "owner@heading.test", "correct-horse-battery" );
		users.assignRole( owner.getId(), roles.getRoleBySlugForSite( "owner", site.getId() ).getId() );
	}

	private function cleanup(){
		queryExecute( "DELETE FROM sites WHERE slug LIKE :p", { p : PREFIX & "%" } );
	}

}
