/**
 * The FAQs module: questions and answers, a public accordion, and admin CRUD.
 *
 * Requires migrations to have run: `box migrate up`.
 */
component extends="coldbox.system.testing.BaseTestCase" appMapping="/app" {

	variables.PREFIX = "zzt-faq-";

	function beforeAll(){
		super.beforeAll();
		variables.sites  = getInstance( "SiteService@core" );
		variables.faqs   = getInstance( "FaqService@faqs" );
		variables.themes = getInstance( "ThemeService@core" );
		cleanup();
		seed();
	}

	function afterAll(){
		cleanup();
		super.afterAll();
	}

	function run(){
		describe( "FAQs", function(){

			beforeEach( function( currentSpec ){
				setup();
			} );

			describe( "creating and listing", function(){

				it( "creates a FAQ scoped to its site", function(){
					expect( variables.published.getSiteId() ).toBe( siteOne.getId() );
					expect( variables.published.getQuestion() ).toBe( "How do I get started?" );
					expect( variables.published.getIsPublished() ).toBeTrue();
				} );

				it( "refuses a FAQ with no question", function(){
					expect( function(){
						faqs.createFaq( siteId = siteOne.getId(), question = "   " );
					} ).toThrow( type = "Faqs.InvalidFaq" );
				} );

				it( "allows the same question on another site", function(){
					var other = faqs.createFaq(
						siteId      = siteTwo.getId(),
						question    = "How do I get started?",
						answer      = "<p>On site two.</p>",
						isPublished = true
					);

					expect( other.getSiteId() ).toBe( siteTwo.getId() );

					faqs.deleteFaq( other.getId() );
				} );

				it( "lists a site's FAQs in sort order", function(){
					var listed = faqs.getFaqsForSite( siteOne.getId() );

					expect( listed.len() ).toBeGTE( 2 );
					expect( listed[ 1 ].getQuestion() ).toBe( "How do I get started?" );
					expect( listed[ 2 ].getQuestion() ).toBe( "Is this a draft?" );
				} );

				it( "omits drafts from the published list", function(){
					var published = faqs.getPublishedFaqs( siteOne.getId() )
						.map( ( faq ) => faq.getQuestion() );

					expect( published ).toInclude( "How do I get started?" );
					expect( published ).notToInclude( "Is this a draft?" );
				} );

			} );

			describe( "the public accordion", function(){

				it( "serves published FAQs at /faq", function(){
					var html = render( "/faq" );

					// encodeForHTML turns `?` into `&#x3f;`, so assert the
					// stem rather than the punctuated question as typed.
					expect( html ).toInclude( "How do I get started" );
					expect( html ).toInclude( "Open an account" );
					expect( html ).toInclude( "<details" );
					expect( html ).toInclude( "<summary>" );
				} );

				it( "does not show drafts on the public page", function(){
					expect( render( "/faq" ) ).notToInclude( "Is this a draft?" );
				} );

				it( "does not serve one site's FAQs on another's domain", function(){
					expect( render( "/faq", "#PREFIX#two.test" ) ).notToInclude( "How do I get started?" );
				} );

				it( "renders through the site's own theme", function(){
					expect( render( "/faq", "#PREFIX#two.test" ) ).toInclude( 'data-view="starter-faq"' );
				} );

				it( "leaves ordinary pages alone", function(){
					expect( render( "/about" ) ).toInclude( "About this site" );
				} );

			} );

			describe( "the module seams", function(){

				it( "registers a resolver ahead of Pages", function(){
					var registered = getInstance( "ContentResolverRegistry@core" ).getRegistered();

					expect( registered ).toInclude( "FaqContentResolver@faqs" );
					expect( registered.find( "FaqContentResolver@faqs" ) )
						.toBeLT( registered.find( "PageContentResolver@pages" ) );
				} );

				it( "registers its own admin and site navigation", function(){
					expect(
						getInstance( "AdminNavigationRegistry@core" ).getSections().map( ( s ) => s.href )
					).toInclude( "/admin/faqs" );

					expect(
						getInstance( "SiteNavigationRegistry@core" ).getRegistered()
					).toInclude( "FaqNavigationProvider@faqs" );

					expect(
						getInstance( "LinkTargetRegistry@core" ).getRegistered()
					).toInclude( "FaqLinkTargetProvider@faqs" );
				} );

				it( "registers its permissions into Core's catalogue", function(){
					var slugs = getInstance( "RoleService@core" )
						.getAllPermissions()
						.map( ( p ) => p.getSlug() );

					expect( slugs ).toInclude( "faqs.view" );
					expect( slugs ).toInclude( "faqs.manage" );
				} );

			} );

		} );
	}

	/* --------------------------------------------------------------------- */

	private string function render( required string uri, string host = "" ){
		setup();

		var event = this.get(
			route   = arguments.uri,
			headers = { "Host" : len( arguments.host ) ? arguments.host : "#PREFIX#one.test" }
		);

		return event.getRenderedContent() & ( event.getHandlerResults() ?: "" );
	}

	private function seed(){
		variables.siteOne = sites.createSite( name = "FAQ One", slug = PREFIX & "one" );
		sites.addDomain( siteOne.getId(), "#PREFIX#one.test" );

		variables.siteTwo = sites.createSite( name = "FAQ Two", slug = PREFIX & "two" );
		sites.addDomain( siteTwo.getId(), "#PREFIX#two.test" );
		themes.setThemeForSite( siteTwo.getId(), "starter" );

		var page = getInstance( "PageService@pages" ).createPage(
			siteId  = siteOne.getId(),
			title   = "About",
			content = "<p>About this site.</p>"
		);
		getInstance( "PageService@pages" ).publishPage( page.getId() );

		variables.published = faqs.createFaq(
			siteId      = siteOne.getId(),
			question    = "How do I get started?",
			answer      = "<p>Open an account.</p>",
			sortOrder   = 10,
			isPublished = true
		);

		variables.draft = faqs.createFaq(
			siteId      = siteOne.getId(),
			question    = "Is this a draft?",
			answer      = "<p>Yes.</p>",
			sortOrder   = 20,
			isPublished = false
		);
	}

	private function cleanup(){
		queryExecute( "DELETE FROM sites WHERE slug LIKE :p", { p : PREFIX & "%" } );
	}

}
