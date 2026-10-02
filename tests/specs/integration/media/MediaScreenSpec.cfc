/**
 * The Media library screen, through a real routed request.
 *
 * The handler and the service were covered; the *view* was not, which is how a
 * template error there reaches production unseen — the handler compiles, the
 * tests pass, and the screen 500s. These render it.
 *
 * The screen now shows two different cards. An image card offers alt text; a
 * document card offers a title and the `[file]` code to copy. Getting that
 * wrong is not a crash, so it is asserted rather than assumed.
 *
 * Requires migrations to have run: `box migrate up`.
 */
component extends="coldbox.system.testing.BaseTestCase" appMapping="/app" {

	variables.PREFIX   = "zzt-ms-";
	variables.PASSWORD = "correct-horse-battery";

	function beforeAll(){
		super.beforeAll();

		variables.sites = getInstance( "SiteService@core" );
		variables.roles = getInstance( "RoleService@core" );
		variables.users = getInstance( "UserService@core" );
		variables.auth  = getInstance( "AuthenticationService@core" );
		variables.repo  = getInstance( "MediaRepository@media" );

		cleanup();
		seed();
	}

	function afterAll(){
		auth.logout();
		cleanup();
		super.afterAll();
	}

	function run(){
		describe( "The media library screen", function(){

			beforeEach( function(){
				setup();
				auth.logout();
				signIn( variables.owner );
			} );

			afterEach( function(){
				auth.logout();
			} );

			it( "renders the library", function(){
				var html = render( "/admin/media" );

				expect( html ).toInclude( "Media" );
				expect( html ).toInclude( "shot.png" );
				expect( html ).toInclude( "terms.pdf" );
			} );

			it( "states both size limits, not one", function(){
				// An author told "up to 10MB" who is then refused a 14MB PDF
				// the server would in fact have taken was misled by the screen.
				var html = render( "/admin/media" );

				expect( html ).toInclude( "Images:" );
				expect( html ).toInclude( "Documents:" );
				expect( html ).toInclude( "docx" );
			} );

			it( "offers a document the shortcode to copy, not its URL", function(){
				// Pasting the URL into a page makes a link that breaks the day
				// the file is replaced.
				var html = render( "/admin/media" );

				expect( html ).toInclude( '[file id="' & variables.doc.getId() & '"]' );
			} );

			it( "gives a document a title field and an image an alt field", function(){
				// Alt text on a PDF describes a picture that is not there; a
				// title on a photograph is not what any screen reads out.
				var html = render( "/admin/media" );

				// The stored values, which appear only in each card's own
				// input — not in the blank fields of the upload form above.
				expect( html ).toInclude( 'value="Terms of engagement"' );
				expect( html ).toInclude( 'value="A bench"' );
			} );

			it( "shows what sort of document it is", function(){
				expect( render( "/admin/media" ) ).toInclude( "PDF" );
			} );

			describe( "saving details", function(){

				it( "sets a document's title without clearing its alt text", function(){
					// The card posts one field or the other, and the handler
					// used to pass both — so saving a title blanked the alt
					// text, and saving alt text blanked the title.
					var before = repo.findById( variables.doc.getId() );

					adminRequest(
						uri    = "/admin/media/update/" & variables.doc.getId(),
						method = "POST",
						params = { title : "Engagement terms 2027" }
					);

					var after = repo.findById( variables.doc.getId() );

					expect( after.getTitle() ).toBe( "Engagement terms 2027" );
					expect( after.getAltText() ).toBe( before.getAltText() );
				} );

				it( "sets an image's alt text without clearing its title", function(){
					var before = repo.findById( variables.image.getId() );

					adminRequest(
						uri    = "/admin/media/update/" & variables.image.getId(),
						method = "POST",
						params = { altText : "A bench by the river" }
					);

					var after = repo.findById( variables.image.getId() );

					expect( after.getAltText() ).toBe( "A bench by the river" );
					expect( after.getTitle() ).toBe( before.getTitle() );
				} );

			} );

		} );
	}

	/* --------------------------------------------------------------------- */

	private function adminRequest(
		required string uri,
		string method = "GET",
		struct params = {}
	){
		setup();

		var sent = duplicate( arguments.params );

		// Every admin POST carries one, and without it `SecuredHandler`
		// refuses the request — which is how the first version of these two
		// specs "proved" the handler was not saving.
		if ( arguments.method == "POST" && !structKeyExists( sent, "csrfToken" ) ) {
			sent.csrfToken = getInstance( "CsrfService@core" ).getCurrentToken();
		}

		return this.request(
			route   = arguments.uri,
			params  = sent,
			headers = { "Host" : "#PREFIX#one.test" },
			method  = arguments.method
		);
	}

	private string function render( required string uri ){
		var event = adminRequest( uri = arguments.uri );

		return event.getRenderedContent() & ( event.getHandlerResults() ?: "" );
	}

	private function signIn( required any user ){
		getInstance( "TenantContext@core" ).setCurrentTenant( variables.site );
		auth.startSessionFor( arguments.user, variables.site.getId() );

		return this;
	}

	private function seed(){
		variables.site = sites.createSite( name = "Media Screen", slug = PREFIX & "one" );
		sites.addDomain( site.getId(), "#PREFIX#one.test" );
		roles.seedDefaultRolesForSite( site.getId() );

		variables.owner = users.createUser( site.getId(), "Owner", "owner@mediascreen.test", PASSWORD );
		users.assignRole( owner.getId(), roles.getRoleBySlugForSite( "owner", site.getId() ).getId() );

		variables.image = repo.create(
			getInstance( "MediaItem@media" )
				.setSiteId( site.getId() )
				.setFilename( "shot.png" )
				.setOriginalFilename( "shot.png" )
				.setStoredPath( "2026/10/shot-aaaa1111.png" )
				.setExtension( "png" )
				.setMimeType( "image/png" )
				.setKind( "image" )
				.setByteSize( 2048 )
				.setAltText( "A bench" )
				.setTitle( "Bench photograph" )
		);

		variables.doc = repo.create(
			getInstance( "MediaItem@media" )
				.setSiteId( site.getId() )
				.setFilename( "terms.pdf" )
				.setOriginalFilename( "terms.pdf" )
				.setStoredPath( "2026/10/terms-bbbb2222.pdf" )
				.setExtension( "pdf" )
				.setMimeType( "application/pdf" )
				.setKind( "document" )
				.setByteSize( 246000 )
				.setAltText( "" )
				.setTitle( "Terms of engagement" )
		);
	}

	private function cleanup(){
		queryExecute( "DELETE FROM sites WHERE slug LIKE :p", { p : PREFIX & "%" } );
	}

}
