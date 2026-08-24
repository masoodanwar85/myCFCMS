/**
 * The Blog module against a real database, and through real routed requests.
 *
 * Blog exists to test whether the seams from Groups 3-5 hold, so these specs
 * check the seams as much as the feature: that its URLs resolve through Core's
 * registry, that its content is sanitised by the shared service, and that its
 * categories cannot cross a tenant boundary.
 *
 * Requires migrations to have run: `box migrate up`.
 */
component extends="coldbox.system.testing.BaseTestCase" appMapping="/app" {

	variables.PREFIX = "zzt-bg-";

	function beforeAll(){
		super.beforeAll();
		variables.sites  = getInstance( "SiteService@core" );
		variables.themes = getInstance( "ThemeService@core" );
		variables.blog   = getInstance( "BlogService@blog" );
		variables.posts  = getInstance( "PostRepository@blog" );
		cleanup();
		seed();
	}

	function afterAll(){
		cleanup();
		super.afterAll();
	}

	function run(){
		describe( "Blog", function(){

			beforeEach( function( currentSpec ){
				setup();
			} );

			describe( "posts", function(){

				it( "round-trips a post", function(){
					var post = blog.createPost(
						siteId  = siteOne.getId(),
						title   = "A Round Trip",
						content = "<p>Body.</p>"
					);

					var loaded = blog.getPostById( post.getId() );

					expect( loaded.getTitle() ).toBe( "A Round Trip" );
					expect( loaded.getSlug() ).toBe( "a-round-trip" );
					expect( loaded.isDraft() ).toBeTrue();

					blog.deletePost( post.getId() );
				} );

				it( "refuses a duplicate slug on one site", function(){
					expect( function(){
						blog.createPost( siteId = siteOne.getId(), title = "First Post" );
					} ).toThrow( type = "Blog.SlugAlreadyExists" );
				} );

				it( "enforces that in the database, not only in the service", function(){
					expect( function(){
						posts.create(
							getInstance( "Post@blog" )
								.setSiteId( siteOne.getId() )
								.setTitle( "Impostor" )
								.setSlug( "first-post" )
						);
					} ).toThrow( type = "Blog.SlugAlreadyExists" );
				} );

				it( "allows the same slug on a different site", function(){
					var post = blog.createPost( siteId = siteTwo.getId(), title = "First Post" );

					expect( post.getSlug() ).toBe( "first-post" );

					blog.deletePost( post.getId() );
				} );

				it( "stamps a publication date on first publish and keeps it", function(){
					var post = blog.createPost( siteId = siteOne.getId(), title = "Dated" );

					blog.publishPost( post.getId() );
					var first = blog.getPostById( post.getId() ).getPublishedAt();

					blog.unpublishPost( post.getId() );
					blog.publishPost( post.getId() );

					expect( dateTimeFormat( blog.getPostById( post.getId() ).getPublishedAt(), "iso" ) )
						.toBe( dateTimeFormat( first, "iso" ) );

					blog.deletePost( post.getId() );
				} );

				it( "derives an excerpt from the content when none is given", function(){
					var post = blog.createPost(
						siteId  = siteOne.getId(),
						title   = "Excerpted",
						content = "<p>The <b>quick</b> brown fox.</p>"
					);

					var excerpt = blog.getPostById( post.getId() ).getEffectiveExcerpt();

					expect( excerpt ).toInclude( "quick brown fox" );
					expect( excerpt ).notToInclude( "<b>" );

					blog.deletePost( post.getId() );
				} );

				it( "rejects an empty title", function(){
					expect( function(){
						blog.createPost( siteId = siteOne.getId(), title = "  " );
					} ).toThrow( type = "Blog.InvalidPost" );
				} );

				it( "rejects an author from another site", function(){
					expect( function(){
						blog.createPost(
							siteId   = siteOne.getId(),
							title    = "Wrong Author",
							authorId = variables.otherUser.getId()
						);
					} ).toThrow( type = "Blog.InvalidAuthor" );
				} );

			} );

			describe( "content sanitising", function(){

				it( "strips script from a post by an ordinary author", function(){
					var post = blog.createPost(
						siteId  = siteOne.getId(),
						title   = "Sanitised",
						content = "<p>ok</p><" & "script>alert(1)</" & "script>"
					);

					var stored = blog.getPostById( post.getId() ).getContent();

					expect( stored ).notToInclude( "alert" );
					expect( stored ).toInclude( "ok" );

					blog.deletePost( post.getId() );
				} );

				it( "keeps raw markup when the caller says the author is trusted", function(){
					var raw  = "<" & "script>analytics()</" & "script>";
					var post = blog.createPost(
						siteId  = siteOne.getId(),
						title   = "Trusted",
						content = raw,
						allowUnfilteredHtml = true
					);

					expect( blog.getPostById( post.getId() ).getContent() ).toInclude( "analytics" );

					blog.deletePost( post.getId() );
				} );

				it( "sanitises on update too", function(){
					var post = blog.createPost( siteId = siteOne.getId(), title = "Edited Later" );

					blog.updatePost(
						postId  = post.getId(),
						content = '<img src="x" onerror="steal()">'
					);

					expect( blog.getPostById( post.getId() ).getContent() ).notToInclude( "onerror" );

					blog.deletePost( post.getId() );
				} );

			} );

			describe( "categories", function(){

				it( "files a post under a category", function(){
					expect( blog.getCategoryIdsForPost( variables.firstPost.getId() ) )
						.toInclude( variables.announcements.getId() );
				} );

				it( "counts only published posts", function(){
					var counted = blog.getCategoriesWithCounts( siteOne.getId() )
						.filter( ( c ) => c.getId() == variables.announcements.getId() )[ 1 ];

					expect( counted.getPostCount() ).toBe( 1 );
				} );

				it( "refuses a category belonging to another site", function(){
					expect( function(){
						blog.syncCategories(
							variables.firstPost.getId(),
							siteOne.getId(),
							[ variables.otherCategory.getId() ]
						);
					} ).toThrow( type = "Blog.CrossTenantCategory" );
				} );

				it( "refuses it at the database level too", function(){
					expect( function(){
						posts.addCategory(
							variables.firstPost.getId(),
							variables.otherCategory.getId(),
							siteOne.getId()
						);
					} ).toThrow( type = "Blog.CrossTenantCategory" );
				} );

				it( "leaves existing filing intact when a sync set is invalid", function(){
					try {
						blog.syncCategories(
							variables.firstPost.getId(),
							siteOne.getId(),
							[ variables.announcements.getId(), variables.otherCategory.getId() ]
						);
					} catch ( Blog.CrossTenantCategory e ) {
					}

					expect( blog.getCategoryIdsForPost( variables.firstPost.getId() ) )
						.toInclude( variables.announcements.getId() );
				} );

				it( "keeps the posts when a category is deleted", function(){
					var temp = blog.createCategory( siteOne.getId(), "Temporary" );
					var post = blog.createPost(
						siteId      = siteOne.getId(),
						title       = "Filed Temporarily",
						categoryIds = [ temp.getId() ]
					);

					blog.deleteCategory( temp.getId() );

					expect( isNull( blog.getPostById( post.getId() ) ) ).toBeFalse();
					expect( blog.getCategoryIdsForPost( post.getId() ) ).toBeEmpty();

					blog.deletePost( post.getId() );
				} );

			} );

			describe( "public URLs", function(){

				it( "serves the archive", function(){
					var html = render( "/blog" );

					expect( html ).toInclude( "First Post" );
					expect( html ).toInclude( "Second Post" );
				} );

				it( "keeps drafts out of the archive", function(){
					expect( render( "/blog" ) ).notToInclude( "Hidden Draft" );
				} );

				it( "serves a single post", function(){
					var html = render( "/blog/first-post" );

					expect( html ).toInclude( "<title>First Post</title>" );
					expect( html ).toInclude( "Hello world" );
				} );

				it( "does not serve a draft post", function(){
					expect( render( "/blog/hidden-draft" ) ).toInclude( "Page not found" );
				} );

				it( "serves a category archive", function(){
					var html = render( "/blog/category/announcements" );

					expect( html ).toInclude( "Announcements" );
					expect( html ).toInclude( "First Post" );
					expect( html ).notToInclude( "Second Post" );
				} );

				it( "404s an unknown category rather than showing an empty list", function(){
					expect( render( "/blog/category/nonexistent" ) ).toInclude( "Page not found" );
				} );

				it( "404s an unknown post", function(){
					expect( render( "/blog/no-such-post" ) ).toInclude( "Page not found" );
				} );

				it( "does not serve one site's post on another's domain", function(){
					var html = render( "/blog/first-post", "#PREFIX#two.test" );

					expect( html ).notToInclude( "Hello world" );
				} );

				it( "leaves ordinary pages alone", function(){
					expect( render( "/about" ) ).toInclude( "About this site" );
				} );

				it( "renders through the site's own theme", function(){
					expect( render( "/blog", "#PREFIX#two.test" ) ).toInclude( 'data-view="starter-blog-index"' );
				} );

			} );

			describe( "the module seams", function(){

				it( "registers its resolver ahead of Pages", function(){
					var registered = getInstance( "ContentResolverRegistry@core" ).getRegistered();

					expect( registered ).toInclude( "BlogContentResolver@blog" );
					expect( registered.find( "BlogContentResolver@blog" ) )
						.toBeLT( registered.find( "PageContentResolver@pages" ) );
				} );

				it( "registers its own admin navigation", function(){
					var hrefs = getInstance( "AdminNavigationRegistry@core" )
						.getSections()
						.map( ( s ) => s.href );

					expect( hrefs ).toInclude( "/admin/blog" );
				} );

				it( "registers its permissions into Core's catalogue", function(){
					var slugs = getInstance( "RoleService@core" )
						.getAllPermissions()
						.map( ( p ) => p.getSlug() );

					expect( slugs ).toInclude( "blog.publish" );
					expect( slugs ).toInclude( "blog.categories.manage" );
					expect( slugs ).toInclude( "content.unfiltered" );
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
		variables.siteOne = sites.createSite( name = "Blog One", slug = PREFIX & "one" );
		sites.addDomain( siteOne.getId(), "#PREFIX#one.test" );

		variables.siteTwo = sites.createSite( name = "Blog Two", slug = PREFIX & "two" );
		sites.addDomain( siteTwo.getId(), "#PREFIX#two.test" );
		themes.setThemeForSite( siteTwo.getId(), "starter" );

		var page = getInstance( "PageService@pages" ).createPage(
			siteId  = siteOne.getId(),
			title   = "About",
			content = "<p>About this site.</p>"
		);
		getInstance( "PageService@pages" ).publishPage( page.getId() );

		variables.otherUser = getInstance( "UserService@core" )
			.createUser( siteTwo.getId(), "Other", "other@blog.test", "correct-horse-battery" );

		variables.announcements  = blog.createCategory( siteOne.getId(), "Announcements" );
		variables.otherCategory  = blog.createCategory( siteTwo.getId(), "Elsewhere" );

		variables.firstPost = blog.createPost(
			siteId      = siteOne.getId(),
			title       = "First Post",
			content     = "<p>Hello world.</p>",
			categoryIds = [ announcements.getId() ]
		);
		blog.publishPost( firstPost.getId() );

		var second = blog.createPost( siteId = siteOne.getId(), title = "Second Post", content = "<p>More.</p>" );
		blog.publishPost( second.getId() );

		blog.createPost( siteId = siteOne.getId(), title = "Hidden Draft", content = "<p>Secret.</p>" );
	}

	private function cleanup(){
		queryExecute( "DELETE FROM sites WHERE slug LIKE :p", { p : PREFIX & "%" } );
	}

}
