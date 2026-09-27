/**
 * A page's featured image, and how it falls back to its ancestors'.
 *
 * Three properties carry the weight.
 *
 * **It is not `og_image`.** One is shown on the page, the other is the card a
 * social network draws when the page is shared. They are separate fields and
 * setting one must not disturb the other — related only in that an empty
 * `og_image` borrows the featured image rather than the site-wide default.
 *
 * **Inheritance reaches past the parent.** On a four-level tree, a picture on
 * the top of a branch should cover everything beneath it; stopping at the
 * parent leaves the deepest pages — the stubs that need it most — with nothing.
 *
 * **Switching it off means off.** `false` is a real answer, and the usual
 * truthiness shortcuts would make it unsettable.
 *
 * Requires migrations to have run: `box migrate up`.
 */
component extends="coldbox.system.testing.BaseTestCase" appMapping="/app" {

	variables.PREFIX = "zzt-feat-";
	variables.HERO   = "/media/2026/09/legal-hero.jpg";
	variables.OWN    = "/media/2026/09/katoomba.jpg";

	function beforeAll(){
		super.beforeAll();
		variables.pages  = getInstance( "PageService@pages" );
		variables.sites  = getInstance( "SiteService@core" );
		variables.themes = getInstance( "ThemeService@core" );
		cleanup();
		seed();
	}

	function afterAll(){
		cleanup();
		super.afterAll();
	}

	function run(){
		describe( "A page's featured image", function(){

			beforeEach( function(){
				setup();
				// Back to the seeded shape: only the branch root carries one.
				pages.updatePage( pageId = services.getId(), seo = { featuredImage : HERO, inheritFeaturedImage : true } );
				for ( var id in [ wills.getId(), mountains.getId(), katoomba.getId() ] ) {
					pages.updatePage( pageId = id, seo = { featuredImage : "", inheritFeaturedImage : true } );
				}
			} );

			describe( "the field", function(){

				it( "is empty on a new page, with inheritance already on", function(){
					var page = pages.createPage( siteId = site.getId(), title = "Fresh " & createUUID() );

					expect( page.getFeaturedImage() ).toBe( "" );
					expect( page.getInheritFeaturedImage() ).toBeTrue();
				} );

				it( "stores an image and reads it back", function(){
					expect( pages.getPageById( services.getId() ).getFeaturedImage() ).toBe( HERO );
				} );

				it( "is left alone by an update that does not mention it", function(){
					pages.updatePage( pageId = services.getId(), content = "<p>Edited elsewhere.</p>" );

					expect( pages.getPageById( services.getId() ).getFeaturedImage() ).toBe( HERO );
				} );

				it( "can have inheritance switched off, and it stays off", function(){
					pages.updatePage( pageId = wills.getId(), seo = { inheritFeaturedImage : false } );

					expect( pages.getPageById( wills.getId() ).getInheritFeaturedImage() ).toBeFalse();
				} );

			} );

			describe( "resolving which image a page shows", function(){

				it( "uses the page's own when it has one", function(){
					pages.updatePage( pageId = katoomba.getId(), seo = { featuredImage : OWN } );

					var found = resolve( katoomba.getId() );

					expect( found.url ).toBe( OWN );
					expect( found.inherited ).toBeFalse();
				} );

				it( "takes the parent's when it has none", function(){
					var found = resolve( wills.getId() );

					expect( found.url ).toBe( HERO );
					expect( found.inherited ).toBeTrue();
					expect( found.source ).toBe( "Legal Services" );
				} );

				/**
				 * The reason the walk does not stop at the parent. Only the top
				 * of this branch has a picture, and Katoomba is three levels
				 * below it.
				 */
				it( "keeps looking up past a parent that has none", function(){
					var found = resolve( katoomba.getId() );

					expect( found.url ).toBe( HERO );
					expect( found.source ).toBe( "Legal Services" );
				} );

				it( "prefers the nearest ancestor when more than one has an image", function(){
					pages.updatePage( pageId = wills.getId(), seo = { featuredImage : OWN } );

					expect( resolve( katoomba.getId() ).source ).toBe( "Wills" );
				} );

				it( "finds nothing when the page opts out", function(){
					pages.updatePage( pageId = katoomba.getId(), seo = { inheritFeaturedImage : false } );

					expect( resolve( katoomba.getId() ).url ).toBe( "" );
				} );

				/**
				 * An ancestor that has opted out has said its branch takes no
				 * picture from above. Reaching over it would make the setting a
				 * lie for everything beneath.
				 */
				it( "stops at an ancestor that has opted out", function(){
					pages.updatePage( pageId = wills.getId(), seo = { inheritFeaturedImage : false } );

					expect( resolve( katoomba.getId() ).url ).toBe( "" );
				} );

				it( "finds nothing when no page in the branch has one", function(){
					pages.updatePage( pageId = services.getId(), seo = { featuredImage : "" } );

					expect( resolve( katoomba.getId() ).url ).toBe( "" );
				} );

			} );

			describe( "what a URL may be", function(){

				it( "keeps a site-relative media path", function(){
					expect( pages.safeImageUrl( "/media/2026/09/hero.jpg" ) ).toBe( "/media/2026/09/hero.jpg" );
				} );

				it( "keeps an absolute http(s) address", function(){
					expect( pages.safeImageUrl( "https://cdn.example.com/a.png" ) ).toBe( "https://cdn.example.com/a.png" );
				} );

				/**
				 * The whole string is constrained, not just the prefix —
				 * anchoring only the start accepts a valid prefix followed by
				 * an attribute break.
				 */
				it( "refuses anything that would break out of the attribute", function(){
					expect( pages.safeImageUrl( 'https://x" onerror="alert(1)' ) ).toBe( "" );
					expect( pages.safeImageUrl( "javascript:alert(1)" ) ).toBe( "" );
					expect( pages.safeImageUrl( "//evil.example.com/a.png" ) ).toBe( "" );
				} );

			} );

			describe( "the share card", function(){

				/**
				 * Separate fields. A featured image is a better guess for an
				 * empty share card than the site-wide default, which is the
				 * same picture on all 100 pages — but it never overwrites an
				 * `og_image` somebody set deliberately.
				 */
				it( "falls back to the featured image when og:image is blank", function(){
					expect( render( wills ) ).toMatch( 'og:image" content="[^"]*legal-hero\.jpg' );
				} );

				it( "leaves an explicit og:image alone", function(){
					pages.updatePage( pageId = wills.getId(), seo = { ogImage : "/media/2026/09/social.jpg" } );

					var html = render( wills );

					// Scoped to the meta tag: the featured image is also in the
					// body now as a banner, so a page-wide search for it proves
					// nothing about the share card.
					expect( html ).toMatch( 'og:image" content="[^"]*social\.jpg' );
					expect( html ).notToMatch( 'og:image" content="[^"]*legal-hero' );

					pages.updatePage( pageId = wills.getId(), seo = { ogImage : "" } );
				} );

			} );

			describe( "what the theme draws", function(){

				it( "shows a banner on the page that owns the image", function(){
					// The element, not the class name: the theme's stylesheet
					// mentions `.page-hero` on every page, so a bare substring
					// search passes whether a banner rendered or not.
					expect( render( services ) ).toMatch( '<figure class="page-hero"' );
				} );

				/**
				 * The point of the whole feature: a picture on the top of a
				 * branch appears on a page three levels below it, without that
				 * page carrying anything of its own.
				 */
				it( "shows the inherited banner three levels down", function(){
					var html = render( katoomba );

					expect( html ).toMatch( '<figure class="page-hero"' );
					expect( html ).toInclude( "legal-hero.jpg" );
				} );

				it( "draws nothing at all when there is no image to show", function(){
					pages.updatePage( pageId = services.getId(), seo = { featuredImage : "" } );

					expect( render( katoomba ) ).notToMatch( '<figure class="page-hero"' );
				} );

				it( "draws nothing when the page has opted out", function(){
					pages.updatePage( pageId = katoomba.getId(), seo = { inheritFeaturedImage : false } );

					expect( render( katoomba ) ).notToMatch( '<figure class="page-hero"' );
				} );

				/**
				 * Decorative: the heading below it already names the page, and
				 * repeating that as alt text makes a screen reader announce the
				 * title twice.
				 */
				it( "leaves the banner's alt text empty", function(){
					expect( render( katoomba ) ).toMatch( 'class="page-hero"[^!]*alt=""' );
				} );

			} );

			describe( "the editor", function(){

				it( "offers the field with the media picker", function(){
					var html = adminForm( wills.getId() );

					expect( html ).toInclude( 'name="featuredImage"' );
					expect( html ).toInclude( 'data-pick-media="featuredImage"' );
				} );

				it( "says which page an inherited image came from", function(){
					expect( adminForm( wills.getId() ) ).toInclude( "Legal Services" );
				} );

				/**
				 * The tick box does nothing for a page that has its own image,
				 * and saying so beats leaving somebody to wonder.
				 */
				it( "says the tick box has no effect when the page has its own", function(){
					pages.updatePage( pageId = katoomba.getId(), seo = { featuredImage : OWN } );

					expect( adminForm( katoomba.getId() ) ).toInclude( "no effect" );
				} );

			} );

		} );
	}

	/* --------------------------------------------------------------------- */

	private struct function resolve( required numeric pageId ){
		var page = pages.getPageById( arguments.pageId );

		return pages.resolveFeaturedImage( page, pages.getBreadcrumb( arguments.pageId ) );
	}

	private string function render( required any page ){
		setup();

		var event = this.get(
			route   = "/" & pages.getPageById( arguments.page.getId() ).getPath(),
			headers = { "Host" : "#PREFIX#one.test" }
		);

		return event.getRenderedContent() & ( event.getHandlerResults() ?: "" );
	}

	private string function adminForm( required numeric pageId ){
		setup();

		getInstance( "TenantContext@core" ).setCurrentTenant( variables.site );
		getInstance( "AuthenticationService@core" ).startSessionFor( variables.owner, site.getId() );

		var event = this.get(
			route   = "/admin/pages/edit/" & arguments.pageId,
			headers = { "Host" : "#PREFIX#one.test" }
		);

		return event.getRenderedContent() & ( event.getHandlerResults() ?: "" );
	}

	private function seed(){
		variables.site = sites.createSite( name = "Featured Test", slug = PREFIX & "one" );
		sites.addDomain( site.getId(), "#PREFIX#one.test", true );
		themes.setThemeForSite( site.getId(), "default" );

		var roles = getInstance( "RoleService@core" );
		var users = getInstance( "UserService@core" );

		roles.seedDefaultRolesForSite( site.getId() );
		variables.owner = users.createUser( site.getId(), "Owner", "owner@feat.test", "correct-horse-battery" );
		users.assignRole( owner.getId(), roles.getRoleBySlugForSite( "owner", site.getId() ).getId() );

		// The real site's shape: four levels, picture only at the top.
		variables.services  = published( "Legal Services", "zzt-legal-services" );
		variables.wills     = published( "Wills", "zzt-wills", services.getId() );
		variables.mountains = published( "Wills - Blue Mountains", "zzt-wills-bm", wills.getId() );
		variables.katoomba  = published( "Wills - Katoomba", "zzt-wills-kat", mountains.getId() );
	}

	private function published( required string title, required string slug, numeric parentId ){
		var args = {
			siteId  : site.getId(),
			title   : arguments.title,
			slug    : arguments.slug,
			content : "<p>body</p>",
			status  : "published"
		};

		if ( !isNull( arguments.parentId ) ) {
			args.parentId = arguments.parentId;
		}

		var page = pages.createPage( argumentCollection = args );

		pages.publishPage( page.getId() );

		return page;
	}

	private function cleanup(){
		queryExecute( "DELETE FROM sites WHERE slug LIKE :p", { p : PREFIX & "%" } );
	}

}
