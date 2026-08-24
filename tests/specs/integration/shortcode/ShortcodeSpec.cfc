/**
 * Expanding shortcodes, and the shipped handlers.
 *
 * The security specs here matter more than the rest put together. Handler
 * output is **not** sanitised — expansion happens after the AntiSamy pass — so
 * a handler that writes an attribute into its output unescaped has created a
 * stored XSS hole on every page using that shortcode.
 *
 * Requires migrations to have run: `box migrate up`.
 */
component extends="coldbox.system.testing.BaseTestCase" appMapping="/app" {

	variables.PREFIX = "zzt-sc-";

	function beforeAll(){
		super.beforeAll();
		variables.shortcodes = getInstance( "ShortcodeService@core" );
		variables.registry   = getInstance( "ShortcodeRegistry@core" );
		variables.sites      = getInstance( "SiteService@core" );
		variables.blog       = getInstance( "BlogService@blog" );
		variables.media      = getInstance( "MediaRepository@media" );
		cleanup();
		seed();
	}

	function afterAll(){
		cleanup();
		super.afterAll();
	}

	function run(){
		describe( "Shortcodes", function(){

			beforeEach( function( currentSpec ){
				setup();
			} );

			describe( "expansion", function(){

				it( "replaces a known tag", function(){
					expect( expand( "&copy; [year]" ) ).toBe( "&copy; " & dateFormat( now(), "yyyy" ) );
				} );

				it( "leaves an unknown tag exactly as written", function(){
					// Deleting it would make a typo indistinguishable from a
					// shortcode that worked, and would erase content when a
					// module is uninstalled.
					expect( expand( 'a [gallery id="3"] b' ) ).toBe( 'a [gallery id="3"] b' );
				} );

				it( "does not re-scan what a handler produced", function(){
					// A handler emitting another shortcode must not loop.
					registry.register( tag = "zzt-echo", id = "EchoShortcode@zzt" );

					var wb = getWireBox();
					wb.registerNewInstance( name = "EchoShortcode@zzt", instancePath = "tests.resources.EchoShortcode" );

					expect( expand( "[zzt-echo]" ) ).toBe( "[year]" );

					registry.unregister( "zzt-echo" );
				} );

				it( "keeps the page when one shortcode throws", function(){
					var wb = getWireBox();
					wb.registerNewInstance( name = "BoomShortcode@zzt", instancePath = "tests.resources.BoomShortcode" );
					registry.register( tag = "zzt-boom", id = "BoomShortcode@zzt" );

					var out = expand( "before [zzt-boom] after" );

					// The rest of the page survives, and the original text goes
					// back so the author can see which one failed.
					expect( out ).toInclude( "before" );
					expect( out ).toInclude( "after" );
					expect( out ).toInclude( "[zzt-boom]" );

					registry.unregister( "zzt-boom" );
				} );

				it( "reports tags nothing handles", function(){
					var unknown = shortcodes.findUnknownTags( "[gallery][year][nope]" );

					expect( unknown ).toInclude( "gallery" );
					expect( unknown ).toInclude( "nope" );
					expect( unknown ).notToInclude( "year" );
				} );

			} );

			describe( "the registry", function(){

				it( "refuses a second module claiming a tag", function(){
					// Last-registration-wins would silently change what an
					// existing page renders, depending on module load order.
					expect( function(){
						registry.register( tag = "year", id = "SomethingElse@x" );
					} ).toThrow( type = "Shortcode.TagAlreadyRegistered" );
				} );

				it( "is idempotent for the same handler", function(){
					registry.register( tag = "year", id = "SiteShortcodes@core" );

					expect( registry.has( "year" ) ).toBeTrue();
				} );

				it( "lists what a site understands", function(){
					var tags = registry.getRegistered().map( ( r ) => r.tag );

					expect( tags ).toInclude( "year" );
					expect( tags ).toInclude( "recent-posts" );
					expect( tags ).toInclude( "image" );
				} );

			} );

			describe( "attributes are never trusted", function(){

				it( "does not expand a shortcode with a broken quote", function(){
					// The stray `>` ends the attribute nowhere useful, so this
					// is not a shortcode and is left as text. It reaches the
					// page as written — which is safe only because content was
					// sanitised on save. Expansion is not, and is not meant to
					// be, a second line of XSS defence.
					var source = '[image id="' & image.getId() & '" align="right"><b>x</b>"]';

					expect( expand( source ) ).toBe( source );
				} );

				it( "only accepts alignments from a closed list", function(){
					var out = expand( '[image id="' & image.getId() & '" align="evil-class"]' );

					expect( out ).notToInclude( "evil-class" );
					expect( out ).toInclude( "shortcode-image" );
				} );

				it( "escapes alt text coming from the library", function(){
					var out = expand( '[image id="' & hostile.getId() & '"]' );

					// The alt text is a stored string an admin could have made
					// hostile. It must arrive as characters, not as markup.
					expect( out ).toInclude( "&lt;script&gt;" );
					expect( out ).notToInclude( "<script>" );
					expect( out ).notToInclude( "</script>" );
				} );

				it( "clamps a silly post count instead of obeying it", function(){
					var out = expand( '[recent-posts count="9999"]' );

					// The number comes from content anyone with `pages.update`
					// can write, so the cap is the handler's job.
					//
					// Counting with `listLen` would be wrong here: a multi-char
					// list delimiter in CFML is a *set* of delimiters, so "<li"
					// splits on every "<", "l" and "i" in the string.
					var items = out.reMatch( "<li>" ).len();

					expect( items ).toBeLTE( 10 );
					expect( items ).toBeGT( 0 );
				} );

				it( "survives a non-numeric count", function(){
					expect( function(){
						expand( '[recent-posts count="<script>alert(1)</script>"]' );
					} ).notToThrow();
				} );

			} );

			describe( "tenant scoping", function(){

				it( "will not render another site's image", function(){
					// An id in one site's content must not reach another's file.
					var out = expand( '[image id="' & foreignImage.getId() & '"]' );

					expect( out ).toBe( "" );
				} );

				it( "renders nothing for an image that does not exist", function(){
					expect( expand( '[image id="987654321"]' ) ).toBe( "" );
				} );

				it( "renders nothing when the id is missing", function(){
					expect( expand( "[image]" ) ).toBe( "" );
				} );

			} );

		} );
	}

	/* --------------------------------------------------------------------- */

	private string function expand( required string content ){
		return shortcodes.expand( arguments.content, { "siteId" : site.getId(), "path" : "x" } );
	}

	private function storeImage( required numeric siteId, required string alt ){
		return getInstance( "MediaRepository@media" ).create(
			getInstance( "MediaItem@media" )
				.setSiteId( arguments.siteId )
				.setFilename( "a.png" )
				.setOriginalFilename( "a.png" )
				.setStoredPath( "2026/08/" & createUUID() & ".png" )
				.setExtension( "png" )
				.setMimeType( "image/png" )
				.setByteSize( 100 )
				.setAltText( arguments.alt )
				.setTitle( "" )
		);
	}

	private function seed(){
		variables.site  = sites.createSite( name = "Shortcode One", slug = PREFIX & "one" );
		variables.other = sites.createSite( name = "Shortcode Two", slug = PREFIX & "two" );

		sites.addDomain( site.getId(), "#PREFIX#one.test", true );

		variables.image        = storeImage( site.getId(), "A bench" );
		variables.hostile      = storeImage( site.getId(), '"><script>alert(1)</script>' );
		variables.foreignImage = storeImage( other.getId(), "Theirs" );

		for ( var i = 1; i <= 3; i++ ) {
			var post = blog.createPost( siteId = site.getId(), title = "Post #i#", content = "<p>x</p>" );
			blog.publishPost( post.getId() );
		}
	}

	private function cleanup(){
		queryExecute( "DELETE FROM sites WHERE slug LIKE :p", { p : PREFIX & "%" } );
	}

}
