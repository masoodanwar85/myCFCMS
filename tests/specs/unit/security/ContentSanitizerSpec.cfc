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

			/**
			 * The editor's `htmlSupport` allow-list mirrors these rules, so that
			 * what CKEditor preserves and what the sanitiser keeps are the same
			 * set. When they disagree the author sees markup survive the editor
			 * and then vanish on save, which looks like data loss rather than a
			 * policy.
			 */
			describe( "structural markup", function(){

				it( "keeps a div, with its class", function(){
					var clean = sanitizer.sanitize( '<div class="callout">hello</div>' );

					expect( clean ).toInclude( "<div" );
					expect( clean ).toInclude( 'class="callout"' );
				} );

				it( "keeps nested divs", function(){
					var clean = sanitizer.sanitize( '<div class="wrap"><div class="inner"><p>deep</p></div></div>' );

					expect( clean ).toInclude( "inner" );
					expect( clean ).toInclude( "<p>deep</p>" );
				} );

				it( "keeps an inline span", function(){
					expect( sanitizer.sanitize( '<p>a <span class="lead">b</span> c</p>' ) )
						.toInclude( '<span class="lead">' );
				} );

				/**
				 * The editor now grants `class` on every tag the policy
				 * validates, rather than on `div`, `span`, `a` and `button`
				 * only. These are the server half of that claim: if any of
				 * them fails, the editor is allowing more than the sanitiser
				 * keeps, and an author will watch a class vanish on save.
				 */
				it( "keeps a class on ordinary content tags", function(){
					var tags = [
						"p", "h1", "h2", "h3", "blockquote", "ul", "ol", "li",
						"strong", "em", "code", "pre", "section", "article",
						"figure", "figcaption", "mark", "small", "sub", "sup"
					];

					for ( var tag in tags ) {
						var clean = sanitizer.sanitize( "<#tag# class=""x-#tag#"">t</#tag#>" );

						expect( clean ).toInclude( "x-" & tag, "class lost on <" & tag & ">" );
					}
				} );

				it( "keeps a class on table parts", function(){
					var clean = sanitizer.sanitize(
						'<table class="data"><thead><tr><th class="num">1</th></tr></thead>'
						& '<tbody><tr class="row"><td class="cell">2</td></tr></tbody></table>'
					);

					for ( var expected in [ "data", "num", "row", "cell" ] ) {
						expect( clean ).toInclude( expected, "class lost: " & expected );
					}
				} );

				it( "drops a class on the tags the policy truncates", function(){
					// `br`, `col` and `hr` are `truncate`: the tag is kept and
					// every attribute on it is dropped. The editor leaves them
					// out of its class rule for exactly this reason, and this
					// is what would catch the policy changing underneath it.
					for ( var tag in [ "br", "hr" ] ) {
						var clean = sanitizer.sanitize( "<p>a<#tag# class=""gone"">b</p>" );

						expect( clean ).toInclude( "<" & tag );
						expect( clean ).notToInclude( "gone" );
					}
				} );

				it( "still validates the class value itself", function(){
					// `class` is global, but its value goes through the
					// `cssClass` regexp - letters, digits, hyphen, underscore
					// and whitespace. A quote-breaking value is not a class.
					var clean = sanitizer.sanitize( '<p class="a&quot; onclick=&quot;alert(1)">x</p>' );

					expect( clean ).notToInclude( "onclick" );
				} );

				it( "keeps a class on a link, which the editor also keeps", function(){
					var clean = sanitizer.sanitize( '<p><a class="btn" href="/will">Start</a></p>' );

					expect( clean ).toInclude( "<a" );
					expect( clean ).toInclude( 'class="btn"' );
					expect( clean ).toInclude( 'href="/will"' );
				} );

				it( "keeps a button and its class, without form attributes", function(){
					var clean = sanitizer.sanitize(
						'<p><button type="button" class="btn" formaction="/x">Go</button></p>'
					);

					expect( clean ).toInclude( "<button" );
					expect( clean ).toInclude( 'class="btn"' );
					expect( clean ).toInclude( 'type="button"' );
					expect( clean ).notToInclude( "formaction" );
				} );

				it( "drops an event handler on a button", function(){
					var clean = sanitizer.sanitize(
						'<button type="button" class="btn" onclick="alert(1)">Go</button>'
					);

					expect( clean ).notToInclude( "onclick" );
					expect( clean ).notToInclude( "alert" );
					expect( clean ).toInclude( "Go" );
				} );

				it( "drops an id, which the editor also refuses", function(){
					var clean = sanitizer.sanitize( '<div id="x" class="ok">hello</div>' );

					expect( clean ).notToInclude( "id=" );
					expect( clean ).toInclude( 'class="ok"' );
				} );

				it( "drops an event handler on a div", function(){
					var clean = sanitizer.sanitize( '<div onclick="alert(1)" class="ok">hello</div>' );

					expect( clean ).notToInclude( "onclick" );
					expect( clean ).notToInclude( "alert" );
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
