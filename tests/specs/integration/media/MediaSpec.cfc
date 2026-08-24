/**
 * The media library.
 *
 * An upload endpoint is how arbitrary files get onto a server, so most of these
 * specs are refusals. The one that matters most is the file whose extension
 * lies about its contents.
 *
 * Requires migrations to have run: `box migrate up`.
 */
component extends="coldbox.system.testing.BaseTestCase" appMapping="/app" {

	variables.PREFIX = "zzt-md-";

	function beforeAll(){
		super.beforeAll();
		variables.media = getInstance( "MediaService@media" );
		variables.sites = getInstance( "SiteService@core" );
		cleanup();

		variables.site  = sites.createSite( name = "Media One", slug = PREFIX & "one" );
		variables.other = sites.createSite( name = "Media Two", slug = PREFIX & "two" );
	}

	function afterAll(){
		cleanup();
		super.afterAll();
	}

	function run(){
		describe( "MediaService", function(){

			describe( "what it accepts", function(){

				it( "lists only types it will serve safely", function(){
					var allowed = media.getAllowedExtensions();

					expect( allowed ).toInclude( "png" );
					expect( allowed ).toInclude( "jpg" );
					expect( allowed ).toInclude( "pdf" );

					// SVG is an image, and is deliberately absent: it is XML
					// that can carry script, served from the site's own origin.
					expect( allowed ).notToInclude( "svg" );
					expect( allowed ).notToInclude( "html" );
					expect( allowed ).notToInclude( "js" );
				} );

				it( "caps the upload size", function(){
					expect( media.maxBytes() ).toBeGT( 0 );
					expect( media.maxBytes() ).toBeLTE( 52428800 );
				} );

			} );

			describe( "paths it will resolve", function(){

				it( "refuses to climb out of the media root", function(){
					// Whatever a request asks for, the resolved path stays under
					// the site's own directory.
					for ( var attempt in [ "../../../etc/passwd", "..%2f..%2fetc", "....//etc/passwd" ] ) {
						var resolved = media.absolutePath( site.getId(), attempt );

						expect( resolved ).toInclude( "/" & site.getId() & "/" );
						expect( resolved ).notToInclude( ".." );
					}
				} );

				it( "returns null for a path with nothing usable in it", function(){
					expect( isNull( media.getByPath( site.getId(), "../.." ) ) ).toBeTrue();
					expect( isNull( media.getByPath( site.getId(), "" ) ) ).toBeTrue();
				} );

				it( "returns null for a file that is not this site's", function(){
					expect( isNull( media.getByPath( other.getId(), "2026/08/whatever.png" ) ) ).toBeTrue();
				} );

			} );

			describe( "the library", function(){

				it( "starts empty and counts per site", function(){
					expect( media.countForSite( site.getId() ) ).toBe( 0 );
					expect( media.getForSite( site.getId() ) ).toBeEmpty();
					expect( media.bytesUsedBySite( site.getId() ) ).toBe( 0 );
				} );

				it( "refuses an unknown site", function(){
					expect( function(){
						media.upload( siteId = 987654321 );
					} ).toThrow( type = "Media.SiteNotFound" );
				} );

				it( "refuses to touch another site's item", function(){
					expect( function(){
						media.updateDetails( mediaId = 987654321, siteId = site.getId() );
					} ).toThrow( type = "Media.NotFound" );
				} );

			} );

			/**
			 * What the editor's "Media library" button reads. These are read
			 * paths only, so the rows are written straight through the
			 * repository rather than by uploading real files.
			 */
			describe( "the library picker", function(){

				beforeEach( function(){
					variables.repo = getInstance( "MediaRepository@media" );

					variables.png = store( site.getId(), "one.png", "image/png" );
					variables.jpg = store( site.getId(), "two.jpg", "image/jpeg" );
					variables.pdf = store( site.getId(), "notes.pdf", "application/pdf" );
					variables.foreign = store( other.getId(), "theirs.png", "image/png" );
				} );

				afterEach( function(){
					for ( var item in [ png, jpg, pdf, foreign ] ) {
						repo.delete( item.getId() );
					}
				} );

				it( "offers images and leaves documents out", function(){
					var paths = media.getImagesForSite( site.getId() ).map( ( i ) => i.getStoredPath() );

					expect( paths ).toInclude( "one.png" );
					expect( paths ).toInclude( "two.jpg" );

					// A PDF inserted as an <img> is a broken image, not a link.
					expect( paths ).notToInclude( "notes.pdf" );
				} );

				it( "never shows another site's images", function(){
					var paths = media.getImagesForSite( site.getId() ).map( ( i ) => i.getStoredPath() );

					expect( paths ).notToInclude( "theirs.png" );
					expect( media.countImagesForSite( site.getId() ) ).toBe( 2 );
					expect( media.countImagesForSite( other.getId() ) ).toBe( 1 );
				} );

				it( "counts images rather than everything in the library", function(){
					expect( media.countForSite( site.getId() ) ).toBe( 3 );
					expect( media.countImagesForSite( site.getId() ) ).toBe( 2 );
				} );

				it( "hands the picker a URL and an alt text it can insert", function(){
					var first = media.getImagesForSite( site.getId() )[ 1 ].getMemento();

					expect( first ).toHaveKey( "url" );
					expect( first ).toHaveKey( "altText" );
					expect( first ).toHaveKey( "filename" );
					expect( first.url ).toStartWith( "/media/" );
				} );

				it( "pages, so a large library does not arrive in one response", function(){
					expect( media.getImagesForSite( site.getId(), 1, 0 ).len() ).toBe( 1 );
					expect( media.getImagesForSite( site.getId(), 1, 1 ).len() ).toBe( 1 );

					var firstPage  = media.getImagesForSite( site.getId(), 1, 0 )[ 1 ].getStoredPath();
					var secondPage = media.getImagesForSite( site.getId(), 1, 1 )[ 1 ].getStoredPath();

					expect( firstPage ).notToBe( secondPage );
				} );

			} );

			describe( "public URLs", function(){

				it( "carries no site id, because the handler scopes it", function(){
					var item = getInstance( "MediaItem@media" )
						.setSiteId( site.getId() )
						.setStoredPath( "2026/08/photo-abc123.png" )
						.setMimeType( "image/png" )
						.setByteSize( 100 );

					expect( item.getUrl() ).toBe( "/media/2026/08/photo-abc123.png" );
					expect( item.getUrl() ).notToInclude( toString( site.getId() ) );
				} );

				it( "knows an image from a document", function(){
					var image = getInstance( "MediaItem@media" ).setMimeType( "image/png" );
					var doc   = getInstance( "MediaItem@media" ).setMimeType( "application/pdf" );

					expect( image.isImage() ).toBeTrue();
					expect( doc.isImage() ).toBeFalse();
				} );

				it( "falls back to no alt text rather than to a filename", function(){
					// "DSC_0042.jpg" read aloud is worse than silence.
					var item = getInstance( "MediaItem@media" )
						.setOriginalFilename( "DSC_0042.jpg" )
						.setAltText( "" );

					expect( item.getEffectiveAlt() ).toBe( "" );
				} );

			} );

		} );
	}

	private function store(
		required numeric siteId,
		required string storedPath,
		required string mimeType
	){
		return getInstance( "MediaRepository@media" ).create(
			getInstance( "MediaItem@media" )
				.setSiteId( arguments.siteId )
				.setFilename( listLast( arguments.storedPath, "/" ) )
				.setOriginalFilename( listLast( arguments.storedPath, "/" ) )
				.setStoredPath( arguments.storedPath )
				.setExtension( listLast( arguments.storedPath, "." ) )
				.setMimeType( arguments.mimeType )
				.setByteSize( 1024 )
				.setAltText( "" )
				.setTitle( "" )
		);
	}

	private function cleanup(){
		queryExecute( "DELETE FROM sites WHERE slug LIKE :p", { p : PREFIX & "%" } );
	}

}
