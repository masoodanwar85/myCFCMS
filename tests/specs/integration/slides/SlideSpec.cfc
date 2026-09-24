/**
 * Admin-managed hero slides, the home-template renderer, and `[hero-slider]`.
 *
 * Requires migrations to have run: `box migrate up`.
 */
component extends="coldbox.system.testing.BaseTestCase" appMapping="/app" {

	variables.PREFIX = "zzt-sl-";

	function beforeAll(){
		super.beforeAll();
		variables.sites      = getInstance( "SiteService@core" );
		variables.slides     = getInstance( "SlideService@slides" );
		variables.shortcodes = getInstance( "ShortcodeService@core" );
		variables.pages      = getInstance( "PageService@pages" );
		cleanup();
		seed();
	}

	function afterAll(){
		cleanup();
		super.afterAll();
	}

	function run(){
		describe( "Slides", function(){

			beforeEach( function( currentSpec ){
				setup();
			} );

			describe( "creating and listing", function(){

				it( "creates a slide scoped to its site", function(){
					expect( variables.live.getSiteId() ).toBe( siteOne.getId() );
					expect( variables.live.getImageUrl() ).toBe( "/media/hero.jpg" );
					expect( variables.live.getHAlign() ).toBe( "left" );
					expect( variables.live.getVAlign() ).toBe( "middle" );
					expect( variables.live.getIsPublished() ).toBeTrue();
				} );

				it( "refuses a slide with neither an image nor overlay HTML", function(){
					expect( function(){
						slides.createSlide( siteId = siteOne.getId() );
					} ).toThrow( type = "Slides.InvalidSlide" );
				} );

				it( "refuses a javascript image URL", function(){
					expect( function(){
						slides.createSlide(
							siteId      = siteOne.getId(),
							imageUrl    = "javascript:alert(1)",
							overlayHtml = "<p>x</p>"
						);
					} ).toThrow( type = "Slides.InvalidSlide" );
				} );

				it( "falls back unknown alignments to left and middle", function(){
					var slide = slides.createSlide(
						siteId      = siteOne.getId(),
						overlayHtml = "<p>Aligned</p>",
						hAlign      = "diagonal",
						vAlign      = "elsewhere",
						isPublished = false
					);

					expect( slide.getHAlign() ).toBe( "left" );
					expect( slide.getVAlign() ).toBe( "middle" );

					slides.deleteSlide( slide.getId() );
				} );

				it( "omits drafts from the published list", function(){
					var published = slides.getPublishedSlides( siteOne.getId() );

					expect( published.len() ).toBe( 1 );
					expect( published[ 1 ].getImageUrl() ).toBe( "/media/hero.jpg" );
					expect( published[ 1 ].getOverlayHtml() ).notToInclude( "Draft overlay" );
				} );

				it( "allows the same image URL on another site", function(){
					var other = slides.createSlide(
						siteId      = siteTwo.getId(),
						imageUrl    = "/media/hero.jpg",
						overlayHtml = "<p>Site two</p>",
						isPublished = true
					);

					expect( other.getSiteId() ).toBe( siteTwo.getId() );

					slides.deleteSlide( other.getId() );
				} );

			} );

			describe( "rendering", function(){

				it( "renders published slides as a hero", function(){
					var html = slides.renderHeroSlider( siteOne.getId() );

					expect( html ).toInclude( "data-hero-slider" );
					expect( html ).toInclude( "Start your Will" );
					expect( html ).toInclude( "/media/hero.jpg" );
					expect( html ).toInclude( "is-left" );
					expect( html ).toInclude( "is-middle" );
					expect( html ).toInclude( "is-active" );
					expect( html ).notToInclude( "Draft overlay" );
				} );

				it( "renders every published slide so the carousel can move", function(){
					var second = slides.createSlide(
						siteId      = siteOne.getId(),
						imageUrl    = "/media/hero-two.jpg",
						overlayHtml = "<h1>Power of Attorney</h1>",
						hAlign      = "right",
						vAlign      = "bottom",
						sortOrder   = 30,
						isPublished = true
					);

					var html = slides.renderHeroSlider( siteOne.getId() );

					expect( html ).toInclude( "/media/hero.jpg" );
					expect( html ).toInclude( "/media/hero-two.jpg" );
					expect( html ).toInclude( "Start your Will" );
					expect( html ).toInclude( "Power of Attorney" );
					expect( html ).toInclude( "splide__toggle" );
					expect( html ).toInclude( "is-right" );
					expect( html ).toInclude( "is-bottom" );

					slides.deleteSlide( second.getId() );
				} );

				it( "returns nothing when a site has no published slides", function(){
					expect( slides.renderHeroSlider( siteTwo.getId() ) ).toBe( "" );
				} );

				it( "expands [hero-slider] in page content", function(){
					var html = shortcodes.expand(
						"[hero-slider]",
						{ "siteId" : siteOne.getId(), "path" : "about" }
					);

					expect( html ).toInclude( "data-hero-slider" );
					expect( html ).toInclude( "Start your Will" );
				} );

				it( "leaves [hero-slider] empty on a site with no published slides", function(){
					expect(
						shortcodes.expand(
							"[hero-slider]",
							{ "siteId" : siteTwo.getId(), "path" : "about" }
						)
					).toBe( "" );
				} );

				it( "serves the shortcode on a public page", function(){
					var html = render( "/about" );

					expect( html ).toInclude( "data-hero-slider" );
					expect( html ).toInclude( "Start your Will" );
				} );

			} );

			describe( "the module seams", function(){

				it( "registers its shortcode and admin navigation", function(){
					expect( getInstance( "ShortcodeRegistry@core" ).has( "hero-slider" ) ).toBeTrue();

					expect(
						getInstance( "AdminNavigationRegistry@core" ).getSections().map( ( s ) => s.href )
					).toInclude( "/admin/slides" );
				} );

				it( "registers its permissions into Core's catalogue", function(){
					var slugs = getInstance( "RoleService@core" )
						.getAllPermissions()
						.map( ( p ) => p.getSlug() );

					expect( slugs ).toInclude( "slides.view" );
					expect( slugs ).toInclude( "slides.manage" );
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
		variables.siteOne = sites.createSite( name = "Slides One", slug = PREFIX & "one" );
		sites.addDomain( siteOne.getId(), "#PREFIX#one.test" );

		variables.siteTwo = sites.createSite( name = "Slides Two", slug = PREFIX & "two" );
		sites.addDomain( siteTwo.getId(), "#PREFIX#two.test" );

		var page = pages.createPage(
			siteId  = siteOne.getId(),
			title   = "About",
			content = "<p>Intro</p>[hero-slider]<p>Outro</p>"
		);
		pages.publishPage( page.getId() );

		variables.live = slides.createSlide(
			siteId      = siteOne.getId(),
			imageUrl    = "/media/hero.jpg",
			imageAlt    = "Family",
			overlayHtml = "<h1>Start your Will</h1><p><a class=""btn"" href=""/will"">Begin</a></p>",
			hAlign      = "left",
			vAlign      = "middle",
			sortOrder   = 10,
			isPublished = true
		);

		variables.draft = slides.createSlide(
			siteId      = siteOne.getId(),
			overlayHtml = "<p>Draft overlay</p>",
			sortOrder   = 20,
			isPublished = false
		);
	}

	private function cleanup(){
		queryExecute( "DELETE FROM sites WHERE slug LIKE :p", { p : PREFIX & "%" } );
	}

}
