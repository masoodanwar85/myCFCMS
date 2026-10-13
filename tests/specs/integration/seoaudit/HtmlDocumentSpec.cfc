/**
 * Parsing a fetched page.
 *
 * Every check in this module is only as truthful as this file, so these specs
 * are deliberately hostile: unclosed tags, unquoted attributes, mixed case,
 * attributes in the wrong place. That is what real pages look like, and it is
 * the reason this uses a parser rather than regular expressions.
 *
 * Requires migrations to have run: `box migrate up`.
 */
component extends="coldbox.system.testing.BaseTestCase" appMapping="/app" {

	function run(){
		describe( "HtmlDocument", function(){

			describe( "messy markup", function(){

				it( "parses a page browsers would accept but xmlParse would not", function(){
					var doc = parse( "
						<html><head>
							<title>About us</title>
							<meta name=description content='Who we are'>
						</head><body>
							<h1>About</h1>
							<p>Unclosed paragraph
							<p>Another
							<img src=/a.png>
							<ul><li>one<li>two</ul>
						</body></html>
					" );

					expect( doc.isParsed() ).toBeTrue( doc.getParseError() );
					expect( doc.title() ).toBe( "About us" );
					expect( doc.metaByName( "description" ) ).toBe( "Who we are" );
					expect( doc.headings().len() ).toBe( 1 );
					expect( doc.images().len() ).toBe( 1 );
				} );

				it( "records a parse failure instead of throwing", function(){
					var doc = parse( "" );

					expect( doc.isParsed() ).toBeFalse();
					expect( doc.getParseError() ).notToBeEmpty();

					// And every accessor still answers, so a check written
					// against a broken page does not blow up the run.
					expect( doc.title() ).toBe( "" );
					expect( doc.headings() ).toBeEmpty();
					expect( doc.images() ).toBeEmpty();
					expect( doc.links() ).toBeEmpty();
					expect( doc.wordCount() ).toBe( 0 );
				} );

			} );

			describe( "the head", function(){

				it( "finds meta and link tags whatever their case", function(){
					var doc = parse(
						'<html><head><title>T</title>'
						& '<META NAME="Description" CONTENT="D">'
						& '<meta property="OG:TITLE" content="O">'
						& '<LINK REL="Canonical" HREF="https://x.test/a">'
						& '</head><body><p>x</p></body></html>'
					);

					expect( doc.metaByName( "description" ) ).toBe( "D" );
					expect( doc.metaByProperty( "og:title" ) ).toBe( "O" );
					expect( doc.linkByRel( "canonical" ) ).toBe( "https://x.test/a" );
				} );

				it( "tells og:title from a plain name attribute", function(){
					// Open Graph uses `property`, not `name`. Hand-written head
					// markup gets this wrong constantly, and a parser that
					// conflated them would report the mistake as fine.
					var doc = parse(
						'<html><head><meta name="og:title" content="wrong"></head><body><p>x</p></body></html>'
					);

					expect( doc.metaByProperty( "og:title" ) ).toBe( "" );
				} );

				it( "returns empty rather than throwing for a tag that is not there", function(){
					var doc = parse( "<html><head><title>T</title></head><body><p>x</p></body></html>" );

					expect( doc.metaByName( "description" ) ).toBe( "" );
					expect( doc.linkByRel( "canonical" ) ).toBe( "" );
					expect( doc.metaByProperty( "og:image" ) ).toBe( "" );
				} );

			} );

			describe( "headings", function(){

				it( "counts more than one h1, which is the point of the module", function(){
					// The theme emits an h1 when `showHeading` is on, and an
					// author may write one in the content as well. That
					// combination is invisible in the database and obvious here.
					var doc = parse(
						"<html><body><h1>Theme heading</h1><p>a</p><h1>Author heading</h1></body></html>"
					);

					var ones = doc.headings().filter( ( h ) => h.level == 1 );

					expect( ones.len() ).toBe( 2 );
				} );

				it( "keeps headings in document order, so a skipped level is visible", function(){
					var doc = parse( "<html><body><h1>A</h1><h3>B</h3><h2>C</h2></body></html>" );
					var levels = doc.headings().map( ( h ) => h.level );

					expect( levels ).toBe( [ 1, 3, 2 ] );
				} );

			} );

			describe( "images", function(){

				it( "tells a missing alt from a deliberately empty one", function(){
					// `alt=""` says "this image is decorative" and is correct.
					// A missing `alt` is an omission. Treating them alike would
					// nag about images that are already right.
					var doc = parse(
						'<html><body>'
						& '<img src="/none.png">'
						& '<img src="/decorative.png" alt="">'
						& '<img src="/described.png" alt="A bench">'
						& '</body></html>'
					);

					var images = doc.images();

					expect( images.len() ).toBe( 3 );
					expect( images.filter( ( i ) => !i.hasAlt ).len() ).toBe( 1 );
					expect( images.filter( ( i ) => !i.hasAlt )[ 1 ].src ).toBe( "/none.png" );
				} );

			} );

			describe( "links", function(){

				it( "returns href and text, and ignores anchors that are not links", function(){
					var doc = parse(
						'<html><body>'
						& '<a href="/contact">Contact us</a>'
						& '<a name="top"></a>'
						& '</body></html>'
					);

					expect( doc.links().len() ).toBe( 1 );
					expect( doc.links()[ 1 ].href ).toBe( "/contact" );
					expect( doc.links()[ 1 ].text ).toBe( "Contact us" );
				} );

			} );

			describe( "word count", function(){

				it( "counts readable words", function(){
					var doc = parse( "<html><body><p>one two three</p><p>four five</p></body></html>" );

					expect( doc.wordCount() ).toBe( 5 );
				} );

				it( "does not count script or style contents as words", function(){
					// A page with a large inline script would otherwise look
					// substantial while having nothing to read.
					var doc = parse(
						"<html><head><style>body{color:red;background:blue;margin:0}</style></head>"
						& "<body><p>one two three</p>"
						& "<script>var a = 1; var b = 2; function c(){ return a + b; }</script>"
						& "<noscript>Please enable JavaScript to continue browsing</noscript>"
						& "</body></html>"
					);

					expect( doc.wordCount() ).toBe( 3 );
					expect( doc.bodyText() ).toBe( "one two three" );
				} );

				it( "collapses whitespace rather than counting it", function(){
					var doc = parse( "<html><body><p>one

						two</p>   <p>  three  </p></body></html>" );

					expect( doc.wordCount() ).toBe( 3 );
				} );

			} );

		} );
	}

	/* --------------------------------------------------------------------- */

	private function parse( required string html ){
		return getInstance( "HtmlDocument@seoaudit" ).loadHtml( arguments.html );
	}

}
