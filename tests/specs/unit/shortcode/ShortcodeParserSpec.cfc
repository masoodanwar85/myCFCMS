/**
 * The scanner behind shortcodes.
 *
 * Most of these are about what is *not* a shortcode. Content is full of square
 * brackets — citations, notes, code samples — and a parser that treats every
 * one as markup would mangle ordinary prose.
 */
component extends="coldbox.system.testing.BaseTestCase" appMapping="/app" {

	function beforeAll(){
		super.beforeAll();
		variables.parser = getInstance( "ShortcodeParser@core" );
	}

	function run(){
		describe( "ShortcodeParser", function(){

			describe( "what it recognises", function(){

				it( "reads a bare tag", function(){
					var tokens = tagsIn( "before [year] after" );

					expect( tokens.len() ).toBe( 1 );
					expect( tokens[ 1 ].tag ).toBe( "year" );
					expect( tokens[ 1 ].body ).toBe( "" );
				} );

				it( "reads double, single and unquoted attribute values", function(){
					var t = tagsIn( '[image id="12" align=' & "'right'" & ' width=320]' )[ 1 ];

					expect( t.attributes.id ).toBe( "12" );
					expect( t.attributes.align ).toBe( "right" );
					expect( t.attributes.width ).toBe( "320" );
				} );

				it( "reads an attribute with no value", function(){
					var t = tagsIn( "[button primary]" )[ 1 ];

					expect( t.attributes ).toHaveKey( "primary" );
					expect( t.attributes.primary ).toBe( "" );
				} );

				it( "keeps an attribute value containing spaces and brackets", function(){
					var t = tagsIn( '[note text="see [4] and [5], p. 2"]' )[ 1 ];

					expect( t.attributes.text ).toBe( "see [4] and [5], p. 2" );
				} );

				it( "reads an enclosing shortcode's body", function(){
					var t = tagsIn( "[button url=/x]Read <em>on</em>[/button]" )[ 1 ];

					expect( t.tag ).toBe( "button" );
					expect( t.body ).toBe( "Read <em>on</em>" );
				} );

				it( "lower-cases the tag and attribute names", function(){
					var t = tagsIn( '[Image ID="3"]' )[ 1 ];

					expect( t.tag ).toBe( "image" );
					expect( t.attributes ).toHaveKey( "id" );
				} );

				it( "accepts a trailing slash", function(){
					expect( tagsIn( '[image id="1" /]' )[ 1 ].tag ).toBe( "image" );
				} );

				it( "reads several in one document", function(){
					expect( tagsIn( "[year] and [site-name] and [year]" ).len() ).toBe( 3 );
				} );

			} );

			/**
			 * Content reaches the parser *after* the sanitiser has run, and
			 * AntiSamy encodes quote characters in text. Every shortcode
			 * attribute written in the editor arrives looking like this, so it
			 * is the normal case rather than an edge one.
			 */
			describe( "attributes a sanitiser has been through", function(){

				it( "reads an entity-encoded double quote as a quote", function(){
					var t = tagsIn( "[recent-posts count=&quot;3&quot;]" )[ 1 ];

					// Read naively this is an unquoted value of "&quot;3&quot;",
					// which is not a number — so every count silently fell back
					// to its default.
					expect( t.attributes.count ).toBe( "3" );
				} );

				it( "reads the numeric entity forms too", function(){
					expect( tagsIn( "[image id=&##34;12&##34;]" )[ 1 ].attributes.id ).toBe( "12" );
					expect( tagsIn( "[image id=&##x22;12&##x22;]" )[ 1 ].attributes.id ).toBe( "12" );
					expect( tagsIn( "[image id=&##39;12&##39;]" )[ 1 ].attributes.id ).toBe( "12" );
				} );

				it( "keeps a value containing spaces", function(){
					var t = tagsIn( "[note text=&quot;two words&quot;]" )[ 1 ];

					expect( t.attributes.text ).toBe( "two words" );
				} );

				it( "decodes entities inside a value", function(){
					var t = tagsIn( '[note text="Bar &amp; Grill"]' )[ 1 ];

					expect( t.attributes.text ).toBe( "Bar & Grill" );
				} );

				it( "ignores an unterminated entity quote", function(){
					expect( tagsIn( "[image id=&quot;12 and the rest" ) ).toBeEmpty();
				} );

			} );

			describe( "what it leaves alone", function(){

				it( "ignores a bracket that starts with a digit", function(){
					// Footnote markers are the commonest square brackets in prose.
					expect( tagsIn( "As noted [1] and [2]." ) ).toBeEmpty();
				} );

				it( "ignores prose in brackets", function(){
					expect( tagsIn( "[see fig. 2] and [ibid., p. 4]" ) ).toBeEmpty();
				} );

				it( "ignores an unterminated bracket", function(){
					expect( tagsIn( "an unclosed [year and more text" ) ).toBeEmpty();
				} );

				it( "ignores an unterminated quoted attribute", function(){
					// Otherwise one stray quote swallows the rest of the page.
					expect( tagsIn( '[image id="12 and the rest of the document' ) ).toBeEmpty();
				} );

				it( "leaves content with no brackets untouched", function(){
					var tokens = parser.parse( "<p>Plain content.</p>" );

					expect( tokens.len() ).toBe( 1 );
					expect( tokens[ 1 ].type ).toBe( "text" );
				} );

			} );

			describe( "escaping", function(){

				it( "turns [[tag]] into the literal text [tag]", function(){
					var tokens = parser.parse( "Write [[year]] to show the tag." );

					expect( tokens.len() ).toBe( 1 );
					expect( tokens[ 1 ].type ).toBe( "text" );
					expect( tokens[ 1 ].value ).toBe( "Write [year] to show the tag." );
				} );

			} );

			describe( "the source it keeps", function(){

				it( "records the exact original text, so an unknown tag can be put back", function(){
					var t = tagsIn( 'x [gallery id="3"] y' )[ 1 ];

					expect( t.source ).toBe( '[gallery id="3"]' );
				} );

				it( "records the whole of an enclosing shortcode", function(){
					var t = tagsIn( "[button]Go[/button]" )[ 1 ];

					expect( t.source ).toBe( "[button]Go[/button]" );
				} );

			} );

		} );
	}

	private array function tagsIn( required string content ){
		return parser.parse( arguments.content ).filter( ( t ) => t.type == "shortcode" );
	}

}
