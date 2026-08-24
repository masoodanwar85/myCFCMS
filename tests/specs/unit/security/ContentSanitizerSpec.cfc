/**
 * Content sanitising is what stops `pages.update` and `blog.update` from being
 * permissions to run arbitrary script on a client's public site.
 */
component extends="coldbox.system.testing.BaseTestCase" appMapping="/app" {

	function beforeAll(){
		super.beforeAll();
		variables.sanitizer = getInstance( "ContentSanitizer@core" );
	}

	function afterAll(){
		super.afterAll();
	}

	function run(){
		describe( "ContentSanitizer", function(){

			it( "removes script elements", function(){
				var clean = sanitizer.sanitize( "<p>ok</p><" & "script>alert(1)</" & "script>" );

				expect( clean ).notToInclude( "alert" );
				expect( clean ).toInclude( "ok" );
			} );

			it( "removes inline event handlers", function(){
				var clean = sanitizer.sanitize( '<img src="x" onerror="steal()">' );

				expect( clean ).notToInclude( "onerror" );
				expect( clean ).notToInclude( "steal" );
			} );

			it( "removes javascript: URLs", function(){
				var clean = sanitizer.sanitize( '<a href="javascript:evil()">click</a>' );

				expect( clean ).notToInclude( "javascript:" );
			} );

			describe( "what the editor produces for an image", function(){

				// The exact markup CKEditor 5 writes. If the policy strips any
				// of it, an author's image quietly changes or vanishes on save.
				it( "keeps a library image and its figure", function(){
					var clean = sanitizer.sanitize(
						'<figure class="image"><img src="/media/2026/08/photo.png" alt="A bench"></figure>'
					);

					expect( clean ).toInclude( "/media/2026/08/photo.png" );
					expect( clean ).toInclude( "<figure" );
					expect( clean ).toInclude( 'class="image"' );
					expect( clean ).toInclude( "A bench" );
				} );

				it( "keeps a caption", function(){
					var clean = sanitizer.sanitize(
						'<figure class="image"><img src="/media/a.png"><figcaption>By the door</figcaption></figure>'
					);

					expect( clean ).toInclude( "<figcaption" );
					expect( clean ).toInclude( "By the door" );
				} );

				it( "keeps the class an image style writes", function(){
					var clean = sanitizer.sanitize(
						'<figure class="image image-style-side"><img src="/media/a.png"></figure>'
					);

					expect( clean ).toInclude( "image-style-side" );
				} );

				it( "keeps the width a resized image carries", function(){
					var clean = sanitizer.sanitize(
						'<figure class="image image_resized" style="width:42.5%;"><img src="/media/a.png"></figure>'
					);

					expect( clean ).toInclude( "42.5%" );
				} );

			} );

			/**
			 * Allowing `style` at all is the one place this policy gives ground,
			 * so what it refuses matters as much as what it keeps.
			 */
			describe( "the inline styles it will not carry", function(){

				it( "drops positioning, so an image cannot be laid over the page", function(){
					var clean = sanitizer.sanitize(
						'<figure style="position:fixed;top:0;left:0;width:100%"><img src="/media/a.png"></figure>'
					);

					expect( clean ).notToInclude( "position" );
					expect( clean ).notToInclude( "fixed" );
					expect( clean ).notToInclude( "top" );
					expect( clean ).notToInclude( "left" );
				} );

				it( "drops a javascript: URL hidden in a background", function(){
					var clean = sanitizer.sanitize(
						'<figure style="background:url(javascript:alert(1))"><img src="/media/a.png"></figure>'
					);

					expect( clean ).notToInclude( "javascript" );
					expect( clean ).notToInclude( "alert" );
				} );

				it( "drops a CSS expression", function(){
					var clean = sanitizer.sanitize(
						'<figure style="width:expression(alert(1))"><img src="/media/a.png"></figure>'
					);

					expect( clean ).notToInclude( "expression" );
					expect( clean ).notToInclude( "alert" );
				} );

				it( "refuses style anywhere but an image", function(){
					expect( sanitizer.sanitize( '<p style="width:50%">text</p>' ) ).notToInclude( "style" );
					expect( sanitizer.sanitize( '<div style="width:50%">text</div>' ) ).notToInclude( "style" );
				} );

			} );

			it( "keeps ordinary formatting", function(){
				var clean = sanitizer.sanitize( "<p>Hello <b>there</b> and <em>welcome</em></p>" );

				expect( clean ).toInclude( "<b>" );
				expect( clean ).toInclude( "<em>" );
				expect( clean ).toInclude( "Hello" );
			} );

			it( "leaves plain text alone", function(){
				expect( sanitizer.sanitize( "Just words." ) ).toInclude( "Just words." );
			} );

			it( "passes empty content straight through", function(){
				expect( sanitizer.sanitize( "" ) ).toBe( "" );
				expect( sanitizer.sanitize() ).toBe( "" );
			} );

			it( "does nothing when the author is trusted with raw HTML", function(){
				var raw = "<" & "script>analytics()</" & "script>";

				expect( sanitizer.sanitize( raw, true ) ).toBe( raw );
			} );

			it( "reports whether content would survive unchanged", function(){
				expect( sanitizer.isSafe( "<p>Fine</p>" ) ).toBeTrue();
				expect( sanitizer.isSafe( "<" & "script>bad()</" & "script>" ) ).toBeFalse();
				expect( sanitizer.isSafe( "" ) ).toBeTrue();
			} );

		} );
	}

}
