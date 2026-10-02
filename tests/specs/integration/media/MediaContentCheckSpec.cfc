/**
 * Does the file contain what its name claims?
 *
 * This is the check that stands between an upload endpoint and a server
 * hosting whatever somebody renamed. It is tested against **real files on
 * disk** rather than a mocked reader, because the thing most likely to be wrong
 * is the reading itself: the signature check compares raw bytes, and the
 * previous implementation read them through a UTF-8 decoder and worked only
 * because `%PDF` happens to be ASCII.
 *
 * `verifyContent` is private — it is an internal step of `upload()`, not
 * something a caller should be able to ask for separately — so it is reached
 * here through TestBox's `makePublic`.
 *
 * Requires migrations to have run: `box migrate up`.
 */
component extends="coldbox.system.testing.BaseTestCase" appMapping="/app" {

	function beforeAll(){
		super.beforeAll();

		variables.media  = getInstance( "MediaService@media" );
		variables.verify = makePublic( media, "verifyContent", "checkContent" );
		variables.placer = makePublic( getInstance( "MediaService@media" ), "storeFile", "placeFile" );
		variables.scratch = getTempDirectory() & "zzt-media-check-" & createUUID() & "/";

		// A site id no real site has, so placing files cannot touch a real
		// site's directory. Removed wholesale in afterAll.
		variables.fakeSiteId = 987654321;

		directoryCreate( variables.scratch );
	}

	function afterAll(){
		if ( directoryExists( variables.scratch ) ) {
			directoryDelete( variables.scratch, true );
		}

		var placed = getDirectoryFromPath( media.absolutePath( variables.fakeSiteId, "x" ) );

		if ( directoryExists( placed ) ) {
			directoryDelete( placed, true );
		}

		super.afterAll();
	}

	function run(){
		describe( "verifying uploaded content", function(){

			describe( "signed documents", function(){

				it( "accepts a real PDF", function(){
					var path = binaryFile( "ok.pdf", "255044462D312E340A25E2E3CFD30A" );

					expect( function(){ verify.checkContent( path, "pdf" ); } ).notToThrow();
				} );

				it( "refuses HTML renamed to .pdf", function(){
					// The case the whole check exists for.
					var path = textFile( "evil.pdf", "<html><script>alert(1)</script></html>" );

					expect( function(){ verify.checkContent( path, "pdf" ); } )
						.toThrow( type = "Media.ContentMismatch" );
				} );

				it( "accepts a ZIP-container Office file", function(){
					// `PK\x03\x04` — the bytes a UTF-8 read could mangle, which
					// is why this is read as binary.
					for ( var ext in [ "docx", "xlsx", "pptx" ] ) {
						var path = binaryFile( "ok." & ext, "504B030414000600" );

						expect( function(){ verify.checkContent( path, ext ); } ).notToThrow();
					}
				} );

				it( "accepts the empty and spanned ZIP signatures too", function(){
					// An empty archive starts `PK\x05\x06`, a spanned one
					// `PK\x07\x08`. Both are legitimate files to be handed.
					for ( var signature in [ "504B0506", "504B0708" ] ) {
						var path = binaryFile( "edge-" & signature & ".docx", signature & "0000" );

						expect( function(){ verify.checkContent( path, "docx" ); } ).notToThrow();
					}
				} );

				it( "refuses a PDF renamed to .docx", function(){
					// The extension decides how the file is served, so a
					// mismatch is refused in both directions.
					var path = binaryFile( "wrong.docx", "255044462D312E340A" );

					expect( function(){ verify.checkContent( path, "docx" ); } )
						.toThrow( type = "Media.ContentMismatch" );
				} );

				it( "refuses an empty file", function(){
					var path = variables.scratch & "empty.pdf";

					fileWrite( path, "" );

					expect( function(){ verify.checkContent( path, "pdf" ); } )
						.toThrow( type = "Media.ContentMismatch" );
				} );

				it( "refuses a file it cannot read at all", function(){
					// An unreadable file is not a verified file: the hex read
					// returns empty rather than throwing something unrelated,
					// and empty matches no signature.
					expect( function(){ verify.checkContent( variables.scratch & "nope.pdf", "pdf" ); } )
						.toThrow( type = "Media.ContentMismatch" );
				} );

			} );

			describe( "formats with no signature", function(){

				it( "accepts any bytes as text, because nothing could say otherwise", function(){
					// There is no signature for `txt` or `csv` in existence.
					// What makes this acceptable is not this check but the
					// serving policy: Media.cfc sends every non-image as an
					// attachment with `nosniff`, so a .txt full of HTML is
					// downloaded, never rendered on the site's own origin.
					var path = textFile( "notes.txt", "<html><script>alert(1)</script></html>" );

					expect( function(){ verify.checkContent( path, "txt" ); } ).notToThrow();
					expect( function(){ verify.checkContent( path, "csv" ); } ).notToThrow();
				} );

			} );

			describe( "images", function(){

				it( "refuses a text file renamed to .png", function(){
					// An image is not checked against a signature: it has to
					// decode, which is a far stronger test than a prefix.
					var path = textFile( "evil.png", "<?php echo 1; ?>" );

					expect( function(){ verify.checkContent( path, "png" ); } )
						.toThrow( type = "Media.ContentMismatch" );
				} );

				it( "accepts an image that actually decodes", function(){
					var path = variables.scratch & "real.png";

					imageWrite( imageNew( "", 4, 4, "rgb", "white" ), path );

					expect( function(){ verify.checkContent( path, "png" ); } ).notToThrow();
				} );

			} );

			describe( "placing a verified file", function(){

				it( "keeps a document's extension and dates the folder", function(){
					// `storeFile` is the step between a staged upload and a
					// served file. It was only ever exercised with images.
					var staged = binaryFile( "staged-" & createUUID() & ".pdf", "255044462D312E340A" );
					var placed = placer.placeFile( variables.fakeSiteId, staged, "pdf", "Terms of Engagement 2027.pdf" );

					expect( placed.path ).toMatch( "^\d{4}/\d{2}/" );
					expect( placed.filename ).toEndWith( ".pdf" );

					// A recognisable stem from what the uploader called it,
					// with everything unsafe flattened out.
					expect( placed.filename ).toStartWith( "terms-of-engagement-2027-" );
					expect( placed.filename ).notToInclude( " " );

					// And the bytes actually arrived.
					expect( fileExists( media.absolutePath( variables.fakeSiteId, placed.path ) ) ).toBeTrue();
				} );

				it( "never lets the uploader name the file on disk", function(){
					// The submitted name is recorded for display and never used
					// for a filesystem operation, so a traversal attempt has
					// nowhere to go.
					var staged = binaryFile( "staged-" & createUUID() & ".pdf", "255044462D312E340A" );
					var placed = placer.placeFile( variables.fakeSiteId, staged, "pdf", "../../../etc/passwd" );

					expect( placed.filename ).notToInclude( ".." );
					expect( placed.filename ).notToInclude( "/" );
					expect( placed.path ).notToInclude( ".." );
				} );

				it( "gives two uploads of one filename two paths", function(){
					// The random suffix is what stops the second upload
					// overwriting the first, and what stops an unpublished
					// file's URL being guessable from its name.
					var first = placer.placeFile(
						variables.fakeSiteId,
						binaryFile( "a-" & createUUID() & ".pdf", "255044462D312E340A" ),
						"pdf",
						"rates.pdf"
					);
					var second = placer.placeFile(
						variables.fakeSiteId,
						binaryFile( "b-" & createUUID() & ".pdf", "255044462D312E340A" ),
						"pdf",
						"rates.pdf"
					);

					expect( first.path ).notToBe( second.path );
				} );

			} );

		} );
	}

	/* --------------------------------------------------------------------- */

	private string function binaryFile( required string name, required string hex ){
		var path = variables.scratch & arguments.name;

		fileWrite( path, binaryDecode( arguments.hex, "hex" ) );

		return path;
	}

	private string function textFile( required string name, required string body ){
		var path = variables.scratch & arguments.name;

		fileWrite( path, arguments.body );

		return path;
	}

}
