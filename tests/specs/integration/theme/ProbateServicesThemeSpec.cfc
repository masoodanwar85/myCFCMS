/**
 * The probate-services theme, rendered through real routed requests.
 *
 * Every view and the home template are rendered here, because a template error
 * reaches production unseen otherwise: the handler compiles, the service specs
 * pass, and the page 500s. A theme is almost entirely templates, so almost all
 * of it is only covered this way.
 *
 * The other half is the firm details the design prints in five places. Those
 * assertions are about *absence* as much as presence — a site that has filled
 * nothing in has to get a working header, not a row of empty labels.
 *
 * Requires migrations to have run: `box migrate up`.
 */
component extends="coldbox.system.testing.BaseTestCase" appMapping="/app" {

	variables.PREFIX = "zzt-probate-";

	function beforeAll(){
		super.beforeAll();

		variables.sites  = getInstance( "SiteService@core" );
		variables.pages  = getInstance( "PageService@pages" );
		variables.themes = getInstance( "ThemeService@core" );
		variables.firm    = getInstance( "FirmDetailsService@core" );
		variables.contact = getInstance( "ContactService@contact" );

		cleanup();
		seed();
	}

	function afterAll(){
		cleanup();
		super.afterAll();
	}

	function run(){
		describe( "The probate-services theme", function(){

			beforeEach( function( currentSpec ){
				setup();
			} );

			describe( "the theme itself", function(){

				it( "is installed and offers its home layout", function(){
					var theme = themes.getTheme( "probate-services" );

					expect( theme.getTitle() ).toBe( "Probate Services" );
					expect( theme.templates() ).toInclude( "home" );
				} );

				it( "supplies every view the resolvers can name", function(){
					// A theme missing one of these answers a 500 rather than a
					// page, and only on the URL that needs it — which is how it
					// reaches production.
					var theme = themes.getTheme( "probate-services" );

					for ( var view in [
						"page", "404", "blog-index", "blog-post", "contact-form",
						"contact-sent", "faq", "hero-slider", "will-form", "will-sent"
					] ) {
						expect( theme.hasView( view ) ).toBeTrue( "no [#view#] view" );
					}
				} );

				it( "carries none of the theme it was copied from", function(){
					// It was scaffolded from willcreator. A template left behind
					// is advertised by GET /api/v1/themes and renders with
					// another client's classes if anybody applies it.
					var templates = themes.getTheme( "probate-services" ).templates();

					for ( var stale in [
						"peter-custom-code", "probate-details", "legal-service-locations",
						"service-locations", "service-location-details"
					] ) {
						expect( templates ).notToInclude( stale );
					}
				} );

				it( "is offered in the theme picker", function(){
					var slugs = themes.getInstalledThemes().map( function( theme ){
						return theme.getSlug();
					} );

					expect( slugs ).toInclude( "probate-services" );
				} );

			} );

			describe( "a page", function(){

				it( "renders with the theme's own stylesheet and shell", function(){
					var html = render( "/" & about.getPath() );

					expect( html ).toInclude( "assets/themes/probate-services/css/theme.css" );
					expect( html ).toInclude( "About this firm" );
					expect( html ).toInclude( "class=""site-foot""" );
				} );

				it( "puts the page body in the prose wrapper", function(){
					// Editor HTML has nowhere to carry a class, so the long-form
					// rules key off this one.
					expect( render( "/" & about.getPath() ) ).toInclude( "class=""prose""" );
				} );

				it( "renders a 404 in the site's own theme", function(){
					var html = render( "/" & PREFIX & "no-such-page" );

					expect( html ).toInclude( "That page is not here" );
					expect( html ).toInclude( "assets/themes/probate-services/css/theme.css" );
				} );

			} );

			describe( "the home template", function(){

				it( "renders every section", function(){
					var html = render( "/" & home.getPath() );

					for ( var marker in [
						"Someone steady",
						"Help at every stage of an estate",
						"Plain-English guides",
						"What you can expect when we act for you",
						"A simple process, in four steps",
						"What executors ask us first",
						"Speak with a probate lawyer today"
					] ) {
						expect( html ).toInclude( marker, "the home page is missing: #marker#" );
					}
				} );

				it( "embeds the real enquiry form, not markup shaped like one", function(){
					// The panel goes through the [contact-form] shortcode, so a
					// submission reaches the Contact module's inbox rather than
					// being inputs that post into nothing.
					var html = render( "/" & home.getPath() );

					expect( html ).toInclude( "csrfToken", "the enquiry panel has no real form in it" );
					expect( html ).toInclude( "Send my enquiry" );
				} );

				it( "draws no enquiry panel at all on a site with no contact form", function(){
					// The shortcode answers with an empty string there, and an
					// empty white box under a heading is worse than no box.
					var bare = sites.createSite( name = "No form", slug = PREFIX & "bare" );

					try {
						sites.addDomain( bare.getId(), "##PREFIX##bare.test", true );
						themes.setThemeForSite( bare.getId(), "probate-services" );

						var page = pages.createPage(
							siteId  = bare.getId(),
							title   = "Home",
							slug    = PREFIX & "bare-home",
							content = "",
							seo     = { template : "home" }
						);
						pages.publishPage( page.getId() );

						setup();

						var event = this.request(
							route   = "/" & page.getPath(),
							headers = { "Host" : "##PREFIX##bare.test" },
							method  = "GET"
						);
						var html = event.getRenderedContent() & ( event.getHandlerResults() ?: "" );

						expect( html ).toInclude( "Tell us what has happened" );
						expect( html ).notToInclude( "contact__panel" );
					} finally {
						queryExecute( "DELETE FROM sites WHERE slug = :s", { s : PREFIX & "bare" } );
					}
				} );

				it( "does not print the page's stored copy", function(){
					// A designed landing page sells the work in a glance; the
					// article text stays in the database for when it is wanted.
					expect( render( "/" & home.getPath() ) ).notToInclude( "STORED-HOME-BODY" );
				} );

			} );

			describe( "the firm's details", function(){

				it( "leaves out what has not been set", function(){
					// The state every site starts in. An empty phone must not
					// produce an empty tel: link or a stray label.
					clearFirm();

					var html = render( "/" & home.getPath() );

					expect( html ).notToInclude( "tel:""" );
					expect( html ).notToInclude( "class=""topbar""" );
					expect( html ).notToInclude( "ABN" );
				} );

				it( "prints them once they are set, in the places the design puts them", function(){
					firm.save( site.getId(), {
						trustLine : "Acting for executors since 1994",
						phone     : "02 9000 1234",
						email     : "enquiries@" & PREFIX & "one.test",
						hours     : "Mon to Fri, 8.30am to 5.30pm",
						abn       : "11 222 333 444"
					} );

					var html = render( "/" & home.getPath() );

					expect( html ).toInclude( "Acting for executors since 1994" );
					expect( html ).toInclude( "Mon to Fri, 8.30am to 5.30pm" );
					expect( html ).toInclude( "11 222 333 444" );
					// Printed as written, dialled without the spaces.
					expect( html ).toInclude( "02 9000 1234" );
					expect( html ).toInclude( "tel:0290001234" );

					clearFirm();
				} );

				it( "reaches the home template, not only the layout", function(){
					// They are passed to views and templates as well as to the
					// layout. Without that the header showed the number and the
					// hero and closing call to action beneath it were blank.
					firm.save( site.getId(), { phone : "1300 555 010" } );

					var html = render( "/" & home.getPath() );

					// Three: the layout's top bar and footer, and the template's
					// hero, contact block and closing band.
					expect( html.listLen( "tel:1300555010" ) - 1 ).toBeGTE(
						3,
						"the template's own phone links did not render"
					);

					clearFirm();
				} );

				it( "breaks a multi-line address into lines rather than printing an entity", function(){
					firm.save( site.getId(), { address : "Level 7, 180 Phillip Street" & chr( 10 ) & "Sydney NSW 2000" } );

					var html = render( "/" & home.getPath() );

					expect( html ).toInclude( "Level 7, 180 Phillip Street<br>Sydney NSW 2000" );
					expect( html ).notToInclude( "&##xa;" );

					clearFirm();
				} );

				it( "never lets a stored value escape into a link", function(){
					// Written straight past the service, as a migration or a
					// hand-run UPDATE would. The read path drops it.
					getInstance( "SiteSettingsRepository@core" )
						.put( site.getId(), "firm.phone", "javascript:alert(1)" );

					var html = render( "/" & home.getPath() );

					expect( html ).notToInclude( "javascript:alert(1)" );

					clearFirm();
				} );

			} );

		} );
	}

	/* --------------------------------------------------------------------- */

	private string function render( required string uri ){
		setup();

		var event = this.request(
			route   = arguments.uri,
			headers = { "Host" : "#PREFIX#one.test" },
			method  = "GET"
		);

		return event.getRenderedContent() & ( event.getHandlerResults() ?: "" );
	}

	private function clearFirm(){
		var settings = getInstance( "SiteSettingsRepository@core" );

		for ( var field in firm.getFields() ) {
			settings.put( site.getId(), "firm." & field.key, "" );
		}

		return this;
	}

	private function seed(){
		variables.site = sites.createSite( name = "Probate Services Test", slug = PREFIX & "one" );

		sites.addDomain( site.getId(), "#PREFIX#one.test", true );
		themes.setThemeForSite( site.getId(), "probate-services" );

		// The site's enquiry form. Without one the [contact-form] shortcode
		// renders nothing — correct of it, and not what this theme's main
		// contact panel is here to prove.
		contact.createForm( siteId = site.getId(), name = "Contact us" );

		variables.home = pages.createPage(
			siteId  = site.getId(),
			title   = "Home",
			slug    = PREFIX & "home",
			content = "<p>STORED-HOME-BODY</p>",
			seo     = { template : "home" }
		);
		pages.publishPage( home.getId() );

		variables.about = pages.createPage(
			siteId  = site.getId(),
			title   = "About this firm",
			slug    = PREFIX & "about",
			content = "<p>" & repeatString( "Copy about the practice. ", 20 ) & "</p>"
		);
		pages.publishPage( about.getId() );

		clearFirm();
	}

	private function cleanup(){
		queryExecute( "DELETE FROM sites WHERE slug LIKE :p", { p : PREFIX & "%" } );
	}

}
