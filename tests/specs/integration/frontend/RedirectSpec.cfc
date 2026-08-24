/**
 * Old URLs after content moves.
 *
 * Renaming a page used to break every link already published to it, silently.
 * These specs pin both halves: the old URL keeps working, and the redirect
 * table does not turn into a maze of chains and loops as editors keep editing.
 *
 * Requires migrations to have run: `box migrate up`.
 */
component extends="coldbox.system.testing.BaseTestCase" appMapping="/app" {

	variables.PREFIX = "zzt-rd-";

	function beforeAll(){
		super.beforeAll();
		variables.sites     = getInstance( "SiteService@core" );
		variables.pages     = getInstance( "PageService@pages" );
		variables.blog      = getInstance( "BlogService@blog" );
		variables.redirects = getInstance( "RedirectService@core" );
		cleanup();
		seed();
	}

	function afterAll(){
		cleanup();
		super.afterAll();
	}

	function run(){
		describe( "Redirects after a move", function(){

			beforeEach( function( currentSpec ){
				setup();
			} );

			describe( "renaming a page", function(){

				it( "keeps the old URL working", function(){
					var page = pages.createPage( siteId = site.getId(), title = "Old Name" );
					pages.publishPage( page.getId() );

					pages.updatePage( pageId = page.getId(), slug = "new-name" );

					var moved = redirects.find( site.getId(), "old-name" );

					expect( isNull( moved ) ).toBeFalse();
					expect( moved.toPath ).toBe( "new-name" );
					expect( moved.statusCode ).toBe( 301 );

					pages.deletePage( page.getId() );
				} );

				it( "moves every descendant's URL too", function(){
					var parent = pages.createPage( siteId = site.getId(), title = "Parent" );
					var child  = pages.createPage( siteId = site.getId(), title = "Child", parentId = parent.getId() );
					var grand  = pages.createPage( siteId = site.getId(), title = "Grand", parentId = child.getId() );

					pages.updatePage( pageId = parent.getId(), slug = "renamed" );

					expect( redirects.find( site.getId(), "parent/child" ).toPath ).toBe( "renamed/child" );
					expect( redirects.find( site.getId(), "parent/child/grand" ).toPath ).toBe( "renamed/child/grand" );

					pages.deletePage( parent.getId(), true );
				} );

				it( "collapses a chain rather than following two hops", function(){
					var page = pages.createPage( siteId = site.getId(), title = "First" );

					pages.updatePage( pageId = page.getId(), slug = "second" );
					pages.updatePage( pageId = page.getId(), slug = "third" );

					// Not first -> second -> third.
					expect( redirects.find( site.getId(), "first" ).toPath ).toBe( "third" );
					expect( redirects.find( site.getId(), "second" ).toPath ).toBe( "third" );

					pages.deletePage( page.getId() );
				} );

				it( "survives being renamed back to an earlier name", function(){
					var page = pages.createPage( siteId = site.getId(), title = "Loopy" );

					pages.updatePage( pageId = page.getId(), slug = "moved-away" );

					// This is what previously failed: the old row would have
					// become a redirect to itself.
					expect( function(){
						pages.updatePage( pageId = page.getId(), slug = "loopy" );
					} ).notToThrow();

					// And nothing now redirects away from the live path.
					expect( isNull( redirects.find( site.getId(), "loopy" ) ) ).toBeTrue();
					expect( redirects.find( site.getId(), "moved-away" ).toPath ).toBe( "loopy" );

					pages.deletePage( page.getId() );
				} );

				it( "never records a redirect to itself", function(){
					var page = pages.createPage( siteId = site.getId(), title = "Same" );

					pages.updatePage( pageId = page.getId(), title = "Same Title Changed Only" );

					expect( isNull( redirects.find( site.getId(), "same" ) ) ).toBeTrue();

					pages.deletePage( page.getId() );
				} );

			} );

			describe( "renaming a blog post", function(){

				it( "keeps the old post URL working", function(){
					var post = blog.createPost( siteId = site.getId(), title = "Old Post" );
					blog.publishPost( post.getId() );

					blog.updatePost( postId = post.getId(), slug = "new-post" );

					expect( redirects.find( site.getId(), "blog/old-post" ).toPath ).toBe( "blog/new-post" );

					blog.deletePost( post.getId() );
				} );

			} );

			describe( "serving a moved URL", function(){

				it( "redirects the old path instead of serving a 404", function(){
					var page = pages.createPage( siteId = site.getId(), title = "Movable" );
					pages.publishPage( page.getId() );
					pages.updatePage( pageId = page.getId(), slug = "moved-here" );

					var event = this.get( route = "/movable", headers = { "Host" : "#PREFIX#one.test" } );

					expect( event.getValue( "relocate_URI", "" ) ).toInclude( "moved-here" );

					pages.deletePage( page.getId() );
				} );

				it( "still serves a 404 for a path that never existed", function(){
					setup();

					var html = renderGet( "/never-was-here" );

					expect( html ).toInclude( "Page not found" );
				} );

			} );

			describe( "tenant scoping", function(){

				it( "does not apply one site's redirect on another", function(){
					redirects.record( site.getId(), "shared-path", "somewhere-else" );

					expect( isNull( redirects.find( otherSite.getId(), "shared-path" ) ) ).toBeTrue();

					redirects.forget( site.getId(), "shared-path" );
				} );

				it( "goes with the site when the site is deleted", function(){
					var doomed = sites.createSite( name = "Doomed", slug = PREFIX & "doomed" );
					redirects.record( doomed.getId(), "a", "b" );

					queryExecute( "DELETE FROM sites WHERE id = :id", { id : doomed.getId() } );

					expect( redirects.findForSite( doomed.getId() ) ).toBeEmpty();
				} );

			} );

		} );
	}

	private string function renderGet( required string uri ){
		setup();

		var event = this.get( route = arguments.uri, headers = { "Host" : "#PREFIX#one.test" } );

		return event.getRenderedContent() & ( event.getHandlerResults() ?: "" );
	}

	private function seed(){
		variables.site = sites.createSite( name = "Redirect One", slug = PREFIX & "one" );
		sites.addDomain( site.getId(), "#PREFIX#one.test" );

		variables.otherSite = sites.createSite( name = "Redirect Two", slug = PREFIX & "two" );
		sites.addDomain( otherSite.getId(), "#PREFIX#two.test" );
	}

	private function cleanup(){
		queryExecute( "DELETE FROM sites WHERE slug LIKE :p", { p : PREFIX & "%" } );
	}

}
