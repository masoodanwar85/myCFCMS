/**
 * The per-post "show the title as a heading" switch.
 *
 * The same option `pages` has, and it earns its own specs for the same two
 * reasons. A boolean that only ever goes one way is this codebase's most
 * repeated bug — `?:` and truthiness both swallow `false` — so every layer is
 * exercised with the value off, not just on. And turning it off must change
 * only the on-page heading: the title is still the browser tab, the `<title>`
 * tag, the archive listing and the link text.
 *
 * `updatePost` differs from the pages equivalent in a way worth pinning down:
 * its `showHeading` argument has no default, so an update that omits it leaves
 * the stored value alone. Passing `false` and passing nothing mean different
 * things, and the handler relies on that.
 *
 * Requires migrations to have run: `box migrate up`.
 */
component extends="coldbox.system.testing.BaseTestCase" appMapping="/app" {

	variables.PREFIX = "zzt-phead-";

	function beforeAll(){
		super.beforeAll();
		variables.blog   = getInstance( "BlogService@blog" );
		variables.sites  = getInstance( "SiteService@core" );
		variables.themes = getInstance( "ThemeService@core" );
		cleanup();
		seed();
	}

	function afterAll(){
		getInstance( "AuthenticationService@core" ).logout();
		cleanup();
		super.afterAll();
	}

	function run(){
		describe( "Showing a post's title as a heading", function(){

			describe( "the field itself", function(){

				it( "is on for a post created without mentioning it", function(){
					expect( newPost().getShowHeading() ).toBeTrue();
				} );

				it( "can be turned off, and stays off across a reload", function(){
					var post = newPost( false );

					expect( post.getShowHeading() ).toBeFalse();
					expect( blog.getPostById( post.getId() ).getShowHeading() ).toBeFalse();
				} );

				it( "can be turned back on", function(){
					var post = newPost( false );

					blog.updatePost( postId = post.getId(), showHeading = true );

					expect( blog.getPostById( post.getId() ).getShowHeading() ).toBeTrue();
				} );

				/**
				 * `showHeading` has no default on `updatePost` precisely so
				 * this holds. A default of `true` would turn the heading back
				 * on every time a post was edited from anywhere else.
				 */
				it( "is left alone by an update that does not mention it", function(){
					var post = newPost( false );

					blog.updatePost( postId = post.getId(), content = "<p>Edited elsewhere.</p>" );

					expect( blog.getPostById( post.getId() ).getShowHeading() ).toBeFalse();
				} );

			} );

			describe( "what the site renders", function(){

				it( "prints the heading by default", function(){
					expect( render( publishedPost( "Post Heading Shown", true ) ) )
						.toInclude( "<h1>Post Heading Shown</h1>" );
				} );

				it( "leaves the heading out when the switch is off", function(){
					expect( render( publishedPost( "Post Heading Hidden", false ) ) )
						.notToInclude( "<h1>Post Heading Hidden</h1>" );
				} );

				it( "still renders the post's content", function(){
					expect( render( publishedPost( "Post Content Kept", false ) ) )
						.toInclude( "the body is still here" );
				} );

				it( "keeps the title in the document title", function(){
					expect( render( publishedPost( "Post Tab Kept", false ) ) )
						.toInclude( "<title>Post Tab Kept" );
				} );

				it( "leaves an author-written heading in place", function(){
					var post = publishedPost( "Own Post Headline", false, "<h1>My own headline</h1>" );
					var html = render( post );

					expect( html ).toInclude( "<h1>My own headline</h1>" );
					expect( html ).notToInclude( "<h1>Own Post Headline</h1>" );
				} );

			} );

			describe( "the editor", function(){

				it( "ticks the box for a new post, because that is the default", function(){
					expect( adminForm() ).toMatch( 'name="showHeading"[^>]*checked' );
				} );

				it( "carries the marker that lets an unticked box mean false", function(){
					expect( adminForm() ).toInclude( 'name="contentTabPresent"' );
				} );

				it( "flags a content heading that would duplicate the theme's", function(){
					var post = newPost( true, "<h1>Also a headline</h1>" );

					expect( adminForm( post.getId() ) ).toInclude( "two top-level headings" );
				} );

				it( "does not flag one when the theme's heading is off", function(){
					var post = newPost( false, "<h1>The only headline</h1>" );

					expect( adminForm( post.getId() ) ).notToInclude( "two top-level headings" );
				} );

			} );

		} );
	}

	/* --------------------------------------------------------------------- */

	private function newPost( boolean showHeading = true, string content = "" ){
		return blog.createPost(
			siteId      = site.getId(),
			title       = "Spec " & createUUID(),
			content     = arguments.content,
			showHeading = arguments.showHeading
		);
	}

	private function publishedPost(
		required string title,
		required boolean showHeading,
		string content = "<p>the body is still here</p>"
	){
		var post = blog.createPost(
			siteId      = site.getId(),
			title       = arguments.title,
			slug        = "zzt-" & lCase( replace( arguments.title, " ", "-", "all" ) ),
			content     = arguments.content,
			showHeading = arguments.showHeading
		);

		blog.publishPost( post.getId() );

		return post;
	}

	private string function render( required any post ){
		setup();

		var event = this.get(
			route   = "/blog/" & arguments.post.getSlug(),
			headers = { "Host" : "#PREFIX#one.test" }
		);

		return event.getRenderedContent() & ( event.getHandlerResults() ?: "" );
	}

	private string function adminForm( numeric postId = 0 ){
		setup();

		getInstance( "TenantContext@core" ).setCurrentTenant( variables.site );
		getInstance( "AuthenticationService@core" ).startSessionFor( variables.owner, site.getId() );

		var event = this.get(
			route   = arguments.postId ? "/admin/blog/edit/#arguments.postId#" : "/admin/blog/new",
			headers = { "Host" : "#PREFIX#one.test" }
		);

		return event.getRenderedContent() & ( event.getHandlerResults() ?: "" );
	}

	private function seed(){
		variables.site = sites.createSite( name = "Post Heading Test", slug = PREFIX & "one" );
		sites.addDomain( site.getId(), "#PREFIX#one.test", true );
		themes.setThemeForSite( site.getId(), "default" );

		var roles = getInstance( "RoleService@core" );
		var users = getInstance( "UserService@core" );

		roles.seedDefaultRolesForSite( site.getId() );
		variables.owner = users.createUser( site.getId(), "Owner", "owner@phead.test", "correct-horse-battery" );
		users.assignRole( owner.getId(), roles.getRoleBySlugForSite( "owner", site.getId() ).getId() );
	}

	private function cleanup(){
		queryExecute( "DELETE FROM sites WHERE slug LIKE :p", { p : PREFIX & "%" } );
	}

}
