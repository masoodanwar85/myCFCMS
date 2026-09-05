/**
 * Page templates: a page rendering through a theme file instead of the
 * standard view.
 *
 * The security property is the reason the feature exists in this shape, and it
 * is the one worth guarding: what a page stores is a **name**, never code. A
 * name that could address a file outside the theme's `templates` directory
 * would undo that, so it is reduced on the way in and again on the way out.
 *
 * The other property is that a template is a *display* choice. Naming one that
 * is not installed must leave the page rendering plainly rather than breaking
 * it, and must change nothing about the page's title, SEO or menu position.
 *
 * Requires migrations to have run: `box migrate up`.
 */
component extends="coldbox.system.testing.BaseTestCase" appMapping="/app" {

	variables.PREFIX = "zzt-tpl-";

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
		cleanup();
		super.afterAll();
	}

	function run(){
		describe( "Page templates", function(){

			beforeEach( function(){
				setup();
			} );

			describe( "the field", function(){

				it( "is empty by default, meaning the standard page view", function(){
					expect( newPage().getTemplate() ).toBe( "" );
				} );

				it( "stores a template name and reads it back", function(){
					var page = newPage( { template : "example" } );

					expect( pages.getPageById( page.getId() ).getTemplate() ).toBe( "example" );
				} );

				it( "is left alone by an update that does not mention it", function(){
					var page = newPage( { template : "example" } );

					pages.updatePage( pageId = page.getId(), title = page.getTitle(), content = "<p>Edited.</p>" );

					expect( pages.getPageById( page.getId() ).getTemplate() ).toBe( "example" );
				} );

				it( "can be cleared back to the standard view", function(){
					var page = newPage( { template : "example" } );

					pages.updatePage( pageId = page.getId(), title = page.getTitle(), seo = { template : "" } );

					expect( pages.getPageById( page.getId() ).getTemplate() ).toBe( "" );
				} );

			} );

			describe( "what a template name may be", function(){

				/**
				 * The name becomes part of a file path. Anything that could
				 * climb out of the theme's `templates` directory is stripped
				 * rather than escaped, so it addresses nothing instead of
				 * addressing something else.
				 */
				it( "cannot escape the templates directory", function(){
					expect( pages.safeTemplateName( "../../../public/Application" ) ).notToInclude( "." );
					expect( pages.safeTemplateName( "../../../public/Application" ) ).notToInclude( "/" );
				} );

				it( "keeps an ordinary name intact", function(){
					expect( pages.safeTemplateName( "fee-calculator" ) ).toBe( "fee-calculator" );
					expect( pages.safeTemplateName( "  Fee_Calculator  " ) ).toBe( "fee_calculator" );
				} );

				it( "strips anything that is not a name", function(){
					expect( pages.safeTemplateName( "a b/c\\d.e" ) ).toBe( "abcde" );
				} );

				/**
				 * Cleaned on the way in *and* again in the theme, because a row
				 * can reach the database from a migration, a seed or a direct
				 * UPDATE — not only through this service.
				 */
				it( "is cleaned again by the theme when the path is built", function(){
					var theme = themes.getTheme( "default" );

					expect( theme.templatePath( "../../secret" ) ).notToInclude( ".." );
					expect( theme.hasTemplate( "../../../public/Application" ) ).toBeFalse();
				} );

			} );

			describe( "what a theme offers", function(){

				it( "lists the templates it has", function(){
					expect( themes.getTheme( "default" ).templates() ).toInclude( "example" );
				} );

				it( "reports one it does not have", function(){
					expect( themes.getTheme( "default" ).hasTemplate( "no-such-template" ) ).toBeFalse();
				} );

				it( "returns an empty list for a theme with no templates directory", function(){
					expect( themes.getTheme( "starter" ).templates() ).toBeEmpty();
				} );

			} );

			describe( "what the site renders", function(){

				it( "uses the standard view when no template is chosen", function(){
					var html = render( published( "Plain Page", "" ) );

					expect( html ).notToInclude( 'data-template="example"' );
				} );

				it( "renders through the template when one is chosen", function(){
					var html = render( published( "Templated Page", "example" ) );

					expect( html ).toInclude( 'data-template="example"' );
					expect( html ).toInclude( "the body is still here" );
				} );

				/**
				 * A theme changed or a template renamed must leave a page
				 * rendering plainly, not take it down.
				 */
				it( "falls back to the standard view when the template is gone", function(){
					var page = published( "Missing Template", "no-such-template" );
					var html = render( page );

					expect( html ).toInclude( "the body is still here" );
					expect( html ).notToInclude( 'data-template=' );
				} );

				it( "leaves the page's title and SEO alone either way", function(){
					var html = render( published( "Titled Page", "example" ) );

					expect( html ).toInclude( "<title>Titled Page" );
				} );

			} );

			describe( "the editor", function(){

				it( "offers the theme's templates and a standard option", function(){
					var html = adminForm();

					expect( html ).toInclude( 'name="template"' );
					expect( html ).toInclude( "Standard page" );
					expect( html ).toInclude( '>example<' );
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

	private function published( required string title, required string template ){
		var page = pages.createPage(
			siteId  = site.getId(),
			title   = arguments.title,
			slug    = "zzt-" & lCase( replace( arguments.title, " ", "-", "all" ) ),
			content = "<p>the body is still here</p>",
			status  = "published",
			seo     = { template : arguments.template }
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

	private string function adminForm(){
		setup();

		getInstance( "TenantContext@core" ).setCurrentTenant( variables.site );
		getInstance( "AuthenticationService@core" ).startSessionFor( variables.owner, site.getId() );

		var event = this.get(
			route   = "/admin/pages/new",
			headers = { "Host" : "#PREFIX#one.test" }
		);

		return event.getRenderedContent() & ( event.getHandlerResults() ?: "" );
	}

	private function seed(){
		variables.site = sites.createSite( name = "Template Test", slug = PREFIX & "one" );
		sites.addDomain( site.getId(), "#PREFIX#one.test", true );
		themes.setThemeForSite( site.getId(), "default" );

		var roles = getInstance( "RoleService@core" );
		var users = getInstance( "UserService@core" );

		roles.seedDefaultRolesForSite( site.getId() );
		variables.owner = users.createUser( site.getId(), "Owner", "owner@tpl.test", "correct-horse-battery" );
		users.assignRole( owner.getId(), roles.getRoleBySlugForSite( "owner", site.getId() ).getId() );
	}

	private function cleanup(){
		queryExecute( "DELETE FROM sites WHERE slug LIKE :p", { p : PREFIX & "%" } );
	}

}
