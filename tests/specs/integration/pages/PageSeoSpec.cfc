/**
 * Per-page SEO, sitemap control, scheduling and raw markup.
 *
 * The security specs carry most of the weight. `head_markup`, `body_markup`
 * and `json_ld` are emitted into every visitor's page **without sanitising** —
 * that is what they are for — so the only thing standing between an editor and
 * a script on a client's site is the `content.unfiltered` gate. If these specs
 * pass for the wrong reason, nothing else catches it.
 *
 * Requires migrations to have run: `box migrate up`.
 */
component extends="coldbox.system.testing.BaseTestCase" appMapping="/app" {

	variables.PREFIX = "zzt-pseo-";

	function beforeAll(){
		super.beforeAll();
		variables.pages = getInstance( "PageService@pages" );
		variables.sites = getInstance( "SiteService@core" );
		variables.repo  = getInstance( "PageRepository@pages" );
		cleanup();
		seed();
	}

	function afterAll(){
		cleanup();
		super.afterAll();
	}

	function run(){
		describe( "Page SEO fields", function(){

			beforeEach( function( currentSpec ){
				setup();
				variables.page = pages.createPage(
					siteId = site.getId(),
					title  = "Spec " & createUUID(),
					status = "published"
				);
			} );

			afterEach( function( currentSpec ){
				pages.deletePage( page.getId(), true );
			} );

			describe( "defaults", function(){

				it( "presents exactly as it did before these fields existed", function(){
					// The property that makes the migration safe on a live site.
					expect( page.getRobotsIndex() ).toBeTrue();
					expect( page.getRobotsFollow() ).toBeTrue();
					expect( page.getSitemapInclude() ).toBeTrue();
					expect( page.getOgType() ).toBe( "website" );
					expect( page.getSitemapPriority() ).toBe( 0.5 );
					expect( page.getRobotsDirective() ).toBe( "", "a default page asks for no robots tag at all" );
				} );

			} );

			describe( "the robots directive", function(){

				it( "says nothing when both are on", function(){
					// `index, follow` is what a crawler does anyway; emitting it
					// on every page is noise.
					expect( saved( { robotsIndex : true, robotsFollow : true } ).getRobotsDirective() ).toBe( "" );
				} );

				it( "survives being set to false", function(){
					// The elvis trap: `variables.robotsIndex ?: true` reads a
					// stored `false` as `true`, so a page marked noindex
					// rendered as indexable while being correctly dropped from
					// the sitemap — the two disagreed and only one was right.
					expect( saved( { robotsIndex : false } ).getRobotsDirective() ).toBe( "noindex, follow" );
					expect( saved( { robotsIndex : true, robotsFollow : false } ).getRobotsDirective() ).toBe( "index, nofollow" );
					expect( saved( { robotsIndex : false, robotsFollow : false } ).getRobotsDirective() ).toBe( "noindex, nofollow" );
				} );

				it( "round-trips false through the database", function(){
					saved( { robotsIndex : false, sitemapInclude : false } );

					var reloaded = pages.getPageById( page.getId() );

					expect( reloaded.getRobotsIndex() ).toBeFalse();
					expect( reloaded.getSitemapInclude() ).toBeFalse();
				} );

			} );

			describe( "the sitemap", function(){

				it( "leaves out a page an editor excluded", function(){
					saved( { sitemapInclude : false } );

					expect( sitemapPaths() ).notToInclude( page.getPath() );
				} );

				it( "leaves out a noindex page whatever the sitemap flag says", function(){
					// Advertising a page you have asked not to be indexed is a
					// contradiction a crawler resolves however it likes.
					saved( { sitemapInclude : true, robotsIndex : false } );

					expect( sitemapPaths() ).notToInclude( page.getPath() );
				} );

				it( "carries the page's own priority and frequency", function(){
					saved( { sitemapPriority : 0.9, sitemapChangefreq : "daily" } );

					var entry = sitemapEntry( page.getPath() );

					expect( entry.priority ).toBe( 0.9 );
					expect( entry.changeFrequency ).toBe( "daily" );
				} );

				it( "clamps a priority outside the range instead of refusing the save", function(){
					expect( saved( { sitemapPriority : 9 } ).getSitemapPriority() ).toBe( 1 );
					expect( saved( { sitemapPriority : -4 } ).getSitemapPriority() ).toBe( 0 );
				} );

			} );

			describe( "scheduling", function(){

				it( "hides a page scheduled for the future", function(){
					saved( { publishFrom : dateAdd( "d", 7, now() ) } );

					// Published, and not live. Both are true at once and the
					// admin needs to show the difference.
					var reloaded = pages.getPageById( page.getId() );

					expect( reloaded.isPublished() ).toBeTrue();
					expect( reloaded.isLive() ).toBeFalse();
					expect( reloaded.getScheduleState() ).toBe( "scheduled" );
				} );

				it( "hides a page whose window has closed", function(){
					saved( { publishUntil : dateAdd( "d", -1, now() ) } );

					expect( pages.getPageById( page.getId() ).getScheduleState() ).toBe( "expired" );
				} );

				it( "keeps it out of every query, not just the front controller", function(){
					saved( { publishFrom : dateAdd( "d", 7, now() ) } );

					// Enforced in SQL, so a caller written later cannot forget.
					expect( isNull( repo.findPublishedByPath( site.getId(), page.getPath() ) ) ).toBeTrue();
					expect( sitemapPaths() ).notToInclude( page.getPath() );
				} );

				it( "serves it once the window opens", function(){
					saved( { publishFrom : dateAdd( "d", -1, now() ), publishUntil : dateAdd( "d", 1, now() ) } );

					expect( isNull( repo.findPublishedByPath( site.getId(), page.getPath() ) ) ).toBeFalse();
				} );

				it( "refuses a window that closes before it opens", function(){
					expect( function(){
						saved( { publishFrom : dateAdd( "d", 7, now() ), publishUntil : dateAdd( "d", 1, now() ) } );
					} ).toThrow( type = "Pages.InvalidSchedule" );
				} );

				it( "lets a schedule be removed again", function(){
					saved( { publishFrom : dateAdd( "d", 7, now() ) } );

					// An empty string has to clear it. A generated setter given
					// "" would store an empty string and leave the page stuck
					// outside its own window forever.
					saved( { publishFrom : "" } );

					expect( pages.getPageById( page.getId() ).isLive() ).toBeTrue();
				} );

			} );

			describe( "raw markup is gated", function(){

				it( "ignores it entirely without content.unfiltered", function(){
					pages.updatePage(
						pageId              = page.getId(),
						allowUnfilteredHtml = false,
						seo                 = {
							headMarkup : "<" & "script>alert(1)</" & "script>",
							bodyMarkup : "<" & "script>alert(2)</" & "script>",
							jsonLd     : '{"a":1}'
						}
					);

					var reloaded = pages.getPageById( page.getId() );

					expect( reloaded.getHeadMarkup() ).toBe( "" );
					expect( reloaded.getBodyMarkup() ).toBe( "" );
					expect( reloaded.getJsonLd() ).toBe( "" );
				} );

				it( "stores it for someone who holds the permission", function(){
					pages.updatePage(
						pageId              = page.getId(),
						allowUnfilteredHtml = true,
						seo                 = { headMarkup : '<link rel="me" href="https://example.com">' }
					);

					expect( pages.getPageById( page.getId() ).getHeadMarkup() ).toInclude( 'rel="me"' );
				} );

				it( "cannot break out of the script element with valid JSON", function(){
					// The subtle one. `</script>` is perfectly legal *inside* a
					// JSON string, so the block validates — but an HTML parser
					// ends the script element at the first one it sees,
					// whatever the JSON around it says. That is a script
					// injection hole hiding inside a data field.
					var payload = '{"name":"</' & 'script><' & 'script>alert(1)</' & 'script>"}';

					expect( isJSON( payload ) ).toBeTrue( "the payload must be valid JSON, or this proves nothing" );

					pages.updatePage(
						pageId              = page.getId(),
						allowUnfilteredHtml = true,
						seo                 = { jsonLd : payload }
					);

					var rendered = renderHead();

					// The escape is a backslash before the slash: JSON readers
					// ignore it, HTML parsers no longer see a closing tag.
					expect( rendered ).notToInclude( "</" & "script><" & "script>" );
					expect( rendered ).toInclude( "<\/", "the closing sequence must be broken by a backslash" );
				} );

				it( "refuses JSON-LD that is not JSON", function(){
					// Silently discarded by every consumer otherwise, so an
					// author would get no feedback and a broken block would sit
					// in the page indefinitely.
					expect( function(){
						pages.updatePage(
							pageId              = page.getId(),
							allowUnfilteredHtml = true,
							seo                 = { jsonLd : "not json at all" }
						);
					} ).toThrow( type = "Pages.InvalidPage" );
				} );

			} );

			describe( "URLs are checked", function(){

				it( "refuses a scheme that is not http, https or site-relative", function(){
					for ( var attempt in [ "javascript:alert(1)", "data:text/html,<x>", "vbscript:x", "  javascript:x" ] ) {
						expect( function(){
							saved( { canonicalUrl : attempt } );
						} ).toThrow( type = "Pages.InvalidPage", message = "", detail = "[#attempt#] must be refused" );
					}
				} );

				it( "checks the social image the same way", function(){
					expect( function(){
						saved( { ogImage : "javascript:alert(1)" } );
					} ).toThrow( type = "Pages.InvalidPage" );
				} );

				it( "accepts the forms a real page needs", function(){
					expect( saved( { canonicalUrl : "https://example.com/x" } ).getCanonicalUrl() ).toBe( "https://example.com/x" );
					expect( saved( { ogImage : "/media/a.png" } ).getOgImage() ).toBe( "/media/a.png" );
				} );

			} );

			describe( "closed lists", function(){

				it( "drops a value outside the vocabulary rather than storing it", function(){
					// Nothing an author types may become an arbitrary attribute
					// in the rendered markup.
					var result = saved( {
						ogType            : "<" & "script>",
						twitterCard       : "evil-card",
						sitemapChangefreq : "occasionally"
					} );

					expect( result.getOgType() ).toBe( "website" );
					expect( result.getTwitterCard() ).toBe( "summary_large_image" );
					expect( result.getSitemapChangefreq() ).toBe( "weekly" );
				} );

				it( "keeps a legitimate choice", function(){
					var result = saved( { ogType : "article", twitterCard : "summary", sitemapChangefreq : "daily" } );

					expect( result.getOgType() ).toBe( "article" );
					expect( result.getTwitterCard() ).toBe( "summary" );
					expect( result.getSitemapChangefreq() ).toBe( "daily" );
				} );

			} );

		} );
	}

	/* --------------------------------------------------------------------- */

	private function saved( required struct seo ){
		return pages.updatePage( pageId = page.getId(), seo = arguments.seo );
	}

	/**
	 * The `<head>` Core would emit for this page, as a string.
	 */
	private string function renderHead(){
		var resolution = getInstance( "PageContentResolver@pages" )
			.resolveContent( site.getId(), page.getPath() );

		var meta = getInstance( "SeoService@core" ).metadataFor( site, page.getPath(), resolution );

		savecontent variable="local.markup" {
			var args = { "seo" : meta, "title" : page.getTitle() };

			include "/core/views/seo/_head.cfm";
		}

		return local.markup;
	}

	private array function sitemapPaths(){
		return getInstance( "PageSitemapProvider@pages" )
			.getSitemapEntries( site.getId() )
			.map( ( e ) => e.path );
	}

	private struct function sitemapEntry( required string path ){
		var entries = getInstance( "PageSitemapProvider@pages" )
			.getSitemapEntries( site.getId() )
			.filter( ( e ) => e.path == path );

		return entries.len() ? entries[ 1 ] : {};
	}

	private function seed(){
		variables.site = sites.createSite( name = "Page SEO", slug = PREFIX & "one" );
		sites.addDomain( site.getId(), "#PREFIX#one.test", true );
	}

	private function cleanup(){
		queryExecute( "DELETE FROM sites WHERE slug LIKE :p", { p : PREFIX & "%" } );
	}

}
