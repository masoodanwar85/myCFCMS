/**
 * Paged archives.
 *
 * The archive showed the first ten posts and offered no URL for the rest, so
 * everything older was unreachable rather than merely inconvenient. These specs
 * pin that every post is reachable, and that a page which does not exist is a
 * 404 rather than a second copy of page one.
 *
 * Requires migrations to have run: `box migrate up`.
 */
component extends="coldbox.system.testing.BaseTestCase" appMapping="/app" {

	variables.PREFIX = "zzt-pg-";

	function beforeAll(){
		super.beforeAll();
		variables.sites = getInstance( "SiteService@core" );
		variables.blog  = getInstance( "BlogService@blog" );
		cleanup();
		seed();
	}

	function afterAll(){
		cleanup();
		super.afterAll();
	}

	function run(){
		describe( "Blog pagination", function(){

			beforeEach( function( currentSpec ){
				setup();
			} );

			describe( "the archive", function(){

				it( "shows a full first page", function(){
					expect( countPosts( render( "/blog" ) ) ).toBe( 10 );
				} );

				it( "reaches older posts on later pages", function(){
					expect( countPosts( render( "/blog/page/2" ) ) ).toBe( 10 );
					expect( countPosts( render( "/blog/page/3" ) ) ).toBe( 5 );
				} );

				it( "makes every post reachable across the pages", function(){
					var seen = {};

					for ( var page in [ "/blog", "/blog/page/2", "/blog/page/3" ] ) {
						for ( var slug in slugsOn( render( page ) ) ) {
							seen[ slug ] = true;
						}
					}

					expect( seen.count() ).toBe( 25 );
				} );

				it( "shows no post twice", function(){
					var first  = slugsOn( render( "/blog" ) );
					var second = slugsOn( render( "/blog/page/2" ) );

					for ( var slug in second ) {
						expect( first ).notToInclude( slug );
					}
				} );

				it( "links forward and back", function(){
					expect( render( "/blog" ) ).toInclude( 'rel="next"' );

					var middle = render( "/blog/page/2" );
					expect( middle ).toInclude( 'rel="prev"' );
					expect( middle ).toInclude( 'rel="next"' );

					expect( render( "/blog/page/3" ) ).notToInclude( 'rel="next"' );
				} );

				it( "links back to the bare archive rather than page one", function(){
					// `/blog/page/1` and `/blog` would be the same content at two
					// addresses.
					expect( render( "/blog/page/2" ) ).toInclude( 'href="/blog" rel="prev"' );
				} );

			} );

			describe( "a page that does not exist", function(){

				it( "is a 404, not a repeat of page one", function(){
					var html = render( "/blog/page/4" );

					expect( html ).toInclude( "Page not found" );
					expect( countPosts( html ) ).toBe( 0 );
				} );

				it( "rejects a page number that is not one", function(){
					for ( var uri in [ "/blog/page/0", "/blog/page/abc", "/blog/page/-1", "/blog/page/2/extra" ] ) {
						expect( render( uri ) ).toInclude( "Page not found" );
					}
				} );

				it( "does not treat a post as a paged archive", function(){
					expect( render( "/blog/note-1/page/2" ) ).toInclude( "Page not found" );
				} );

			} );

			describe( "a category archive", function(){

				it( "pages independently of the main archive", function(){
					// 15 posts in this category, so two pages of ten and five.
					expect( countPosts( render( "/blog/category/big" ) ) ).toBe( 10 );
					expect( countPosts( render( "/blog/category/big/page/2" ) ) ).toBe( 5 );
				} );

				it( "404s past the end of a category", function(){
					expect( render( "/blog/category/big/page/3" ) ).toInclude( "Page not found" );
				} );

				it( "shows no pager for a category that fits on one page", function(){
					var html = render( "/blog/category/small" );

					expect( countPosts( html ) ).toBe( 3 );
					expect( html ).notToInclude( 'rel="next"' );
				} );

			} );

		} );
	}

	/* --------------------------------------------------------------------- */

	/**
	 * One copy of the page, not two.
	 *
	 * A handler that returns a string populates both `getHandlerResults()` and
	 * the rendered content, so concatenating them — which the other specs do,
	 * harmlessly, because they only assert `toInclude` — yields the whole
	 * document twice and doubles every count.
	 */
	private string function render( required string uri ){
		setup();

		var event  = this.get( route = arguments.uri, headers = { "Host" : "#PREFIX#one.test" } );
		var result = event.getHandlerResults() ?: "";

		return len( result ) ? result : event.getRenderedContent();
	}

	private numeric function countPosts( required string html ){
		return arrayLen( reMatch( '<section style=', arguments.html ) );
	}

	private array function slugsOn( required string html ){
		return reMatch( 'href="/blog/[a-z0-9-]+"', arguments.html )
			.map( ( match ) => listLast( replace( match, '"', "", "all" ), "/" ) )
			.filter( ( slug ) => slug != "blog" );
	}

	private function seed(){
		variables.site = sites.createSite( name = "Paging", slug = PREFIX & "one" );
		sites.addDomain( site.getId(), "#PREFIX#one.test" );

		var big   = blog.createCategory( site.getId(), "Big" );
		var small = blog.createCategory( site.getId(), "Small" );

		// 25 published posts: three pages at ten per page.
		for ( var i = 1; i <= 25; i++ ) {
			var categories = i <= 15 ? [ big.getId() ] : ( i <= 18 ? [ small.getId() ] : [] );

			var post = blog.createPost(
				siteId      = site.getId(),
				title       = "Note #i#",
				content     = "<p>Body #i#.</p>",
				categoryIds = categories
			);
			blog.publishPost( post.getId() );
		}

		// A draft, to prove counts and pages use published posts only.
		blog.createPost( siteId = site.getId(), title = "Unpublished Note" );
	}

	private function cleanup(){
		queryExecute( "DELETE FROM sites WHERE slug LIKE :p", { p : PREFIX & "%" } );
	}

}
