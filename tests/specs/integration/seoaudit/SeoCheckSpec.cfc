/**
 * The checks themselves.
 *
 * Each is asserted on the thing it is for, and — more importantly — on the
 * thing it must *not* report. A check that fires when the page is fine is worse
 * than one that misses something: the report gets ignored, and then the real
 * findings in it get ignored too.
 *
 * Requires migrations to have run: `box migrate up`.
 */
component extends="coldbox.system.testing.BaseTestCase" appMapping="/app" {

	function beforeAll(){
		super.beforeAll();
		variables.registry = getInstance( "SeoCheckRegistry@seoaudit" );
	}

	function run(){
		describe( "SEO checks", function(){

			describe( "the registry", function(){

				it( "has every shipped check registered", function(){
					var ids = registry.getRegistered();

					for ( var check in [
						"StatusCheck", "TitleCheck", "DescriptionCheck", "HeadingCheck",
						"ImageAltCheck", "CanonicalCheck", "RobotsCheck", "OpenGraphCheck",
						"StructuredDataCheck", "ContentLengthCheck", "UrlShapeCheck"
					] ) {
						expect( ids ).toInclude( check & "@seoaudit" );
					}
				} );

				it( "forces an unrecognised severity to a notice rather than dropping it", function(){
					// A finding with a typo in its severity is still a finding.
					var wb = getWireBox();

					wb.registerNewInstance(
						name         = "ZztOddSeverityCheck@zzt",
						instancePath = "tests.resources.ZztOddSeverityCheck"
					);

					var odd = wb.getInstance( "ZztOddSeverityCheck@zzt" );

					// Through the registry, which is what normalises it.
					registry.register( "ZztOddSeverityCheck@zzt" );

					var findings = registry
						.inspect( page( "<title>Wills and estate planning in Melbourne</title><h1>a</h1><h2>b</h2>" ), context() )
						.filter( ( f ) => f.checkId == "zzt.odd" );

					registry.unregister( "ZztOddSeverityCheck@zzt" );

					expect( findings.len() ).toBe( 1 );
					expect( findings[ 1 ].severity ).toBe( "notice" );
				} );

				it( "survives a check that throws, and keeps the others", function(){
					// One broken check must not cost the other eight on every
					// URL of the site.
					registry.register( "ZztBrokenCheck@zzt" );

					var wb = getWireBox();
					wb.registerNewInstance(
						name         = "ZztBrokenCheck@zzt",
						instancePath = "tests.resources.ZztBrokenCheck"
					);

					var findings = registry.inspect( page( "<title>x</title><h1>a</h1>" ), context() );

					registry.unregister( "ZztBrokenCheck@zzt" );

					// The title is too short, so the real checks still ran.
					expect( findings.len() ).toBeGT( 0 );
				} );

			} );

			describe( "title", function(){

				it( "reports a missing title as an error", function(){
					var found = inspect( "TitleCheck", page( "<h1>a</h1>" ) );

					expect( found.len() ).toBe( 1 );
					expect( found[ 1 ].checkId ).toBe( "title.missing" );
					expect( found[ 1 ].severity ).toBe( "error" );
				} );

				it( "reports length as a warning, never an error", function(){
					// The page works. It just shows less of itself than it could.
					var short = inspect( "TitleCheck", page( "<title>Short</title>" ) );
					var long  = inspect( "TitleCheck", page( "<title>" & repeatString( "Very long title ", 8 ) & "</title>" ) );

					expect( short[ 1 ].checkId ).toBe( "title.tooShort" );
					expect( short[ 1 ].severity ).toBe( "warning" );
					expect( long[ 1 ].checkId ).toBe( "title.tooLong" );
					expect( long[ 1 ].severity ).toBe( "warning" );
				} );

				it( "says nothing about a title of a sensible length", function(){
					var found = inspect(
						"TitleCheck",
						page( "<title>Wills and estate planning in Melbourne</title>" )
					);

					expect( found ).toBeEmpty();
				} );

				it( "notices a title that is only the site name", function(){
					var found = inspect(
						"TitleCheck",
						page( "<title>Will Creator</title>" ),
						{ "siteName" : "Will Creator" }
					);

					var ids = found.map( ( f ) => f.checkId );

					expect( ids ).toInclude( "title.siteNameOnly" );
				} );

			} );

			describe( "headings", function(){

				it( "reports two h1 as an error, which is what this module is for", function(){
					// The theme emits one when `showHeading` is on; the author
					// wrote another in the content. Neither row is wrong.
					var found = inspect(
						"HeadingCheck",
						page( "<h1>Theme heading</h1><p>x</p><h1>Author heading</h1>" )
					);

					var ids = found.map( ( f ) => f.checkId );

					expect( ids ).toInclude( "heading.multipleH1" );
					expect( found.filter( ( f ) => f.checkId == "heading.multipleH1" )[ 1 ].severity )
						.toBe( "error" );
				} );

				it( "names both headings so the duplicate can be found", function(){
					var found = inspect(
						"HeadingCheck",
						page( "<h1>Theme heading</h1><h1>Author heading</h1>" )
					);

					var multiple = found.filter( ( f ) => f.checkId == "heading.multipleH1" )[ 1 ];

					expect( multiple.detail ).toInclude( "Theme heading" );
					expect( multiple.detail ).toInclude( "Author heading" );
				} );

				it( "reports no h1 as an error", function(){
					var ids = inspect( "HeadingCheck", page( "<h2>a</h2>" ) ).map( ( f ) => f.checkId );

					expect( ids ).toInclude( "heading.noH1" );
				} );

				it( "reports a skipped level as a notice only", function(){
					// An outline problem, not a traffic problem. Flagging it
					// loudly would bury the findings that cost money.
					var found = inspect( "HeadingCheck", page( "<h1>a</h1><h3>b</h3>" ) );
					var skip  = found.filter( ( f ) => f.checkId == "heading.skippedLevel" );

					expect( skip.len() ).toBe( 1 );
					expect( skip[ 1 ].severity ).toBe( "notice" );
				} );

				it( "says nothing about a correct outline", function(){
					var found = inspect( "HeadingCheck", page( "<h1>a</h1><h2>b</h2><h3>c</h3><h2>d</h2>" ) );

					expect( found ).toBeEmpty();
				} );

			} );

			describe( "images", function(){

				it( "reports a missing alt but not an empty one", function(){
					// `alt=""` is the correct way to mark an image decorative.
					var found = inspect(
						"ImageAltCheck",
						page( '<img src="/a.png"><img src="/b.png" alt=""><img src="/c.png" alt="A bench">' )
					);

					expect( found.len() ).toBe( 1 );
					expect( found[ 1 ].detail ).toInclude( "/a.png" );
					expect( found[ 1 ].detail ).notToInclude( "/b.png" );
					expect( found[ 1 ].detail ).notToInclude( "/c.png" );
				} );

				it( "says nothing when every image is accounted for", function(){
					var found = inspect(
						"ImageAltCheck",
						page( '<img src="/a.png" alt=""><img src="/b.png" alt="A bench">' )
					);

					expect( found ).toBeEmpty();
				} );

			} );

			describe( "canonical", function(){

				it( "reports a canonical pointing elsewhere as an error", function(){
					// The most damaging fault on the list: the page vanishes
					// from results and nothing on it looks wrong.
					var found = inspect(
						"CanonicalCheck",
						page( '<link rel="canonical" href="https://x.test/other">' ),
						{ "absoluteUrl" : "https://x.test/about" }
					);

					expect( found.len() ).toBe( 1 );
					expect( found[ 1 ].checkId ).toBe( "canonical.mismatch" );
					expect( found[ 1 ].severity ).toBe( "error" );
					expect( found[ 1 ].detail ).toInclude( "https://x.test/other" );
				} );

				it( "ignores a trailing slash, which means nothing to a crawler", function(){
					var found = inspect(
						"CanonicalCheck",
						page( '<link rel="canonical" href="https://x.test/about/">' ),
						{ "absoluteUrl" : "https://x.test/about" }
					);

					expect( found ).toBeEmpty();
				} );

				it( "stays quiet when the site has no primary domain to compare against", function(){
					// That the primary domain is missing is reported once for
					// the site, not on every page.
					var found = inspect(
						"CanonicalCheck",
						page( '<link rel="canonical" href="https://x.test/about">' ),
						{ "absoluteUrl" : "" }
					);

					expect( found ).toBeEmpty();
				} );

			} );

			describe( "robots", function(){

				it( "says nothing when there is no robots tag", function(){
					// The common case by far. A check that fires on every page
					// of a healthy site is a check nobody reads.
					expect( inspect( "RobotsCheck", page( "<h1>About</h1>" ) ) ).toBeEmpty();
				} );

				it( "says nothing when the page asks to be indexed", function(){
					expect(
						inspect( "RobotsCheck", page( '<meta name="robots" content="index, follow">' ) )
					).toBeEmpty();
				} );

				it( "warns about noindex, because the page gets no traffic and looks fine", function(){
					var found = inspect( "RobotsCheck", page( '<meta name="robots" content="noindex">' ) );

					expect( found.len() ).toBe( 1 );
					expect( found[ 1 ].checkId ).toBe( "robots.noindex" );
					// A warning rather than an error: this CMS has an explicit
					// switch for it, so it can be a deliberate choice.
					expect( found[ 1 ].severity ).toBe( "warning" );
				} );

				it( "reads `none` as both noindex and nofollow", function(){
					var ids = inspect( "RobotsCheck", page( '<meta name="robots" content="none">' ) )
						.map( ( f ) => f.checkId );

					expect( ids ).toInclude( "robots.noindex" );
					expect( ids ).toInclude( "robots.nofollow" );
				} );

				it( "reports nofollow on its own as a notice", function(){
					var found = inspect( "RobotsCheck", page( '<meta name="robots" content="index,nofollow">' ) );

					expect( found.len() ).toBe( 1 );
					expect( found[ 1 ].checkId ).toBe( "robots.nofollow" );
					expect( found[ 1 ].severity ).toBe( "notice" );
				} );

				it( "does not read a longer word as a directive", function(){
					// The reason this matches list entries rather than
					// substrings: `noindexing` is not `noindex`, and a
					// substring test would report a page that is perfectly
					// indexable.
					expect(
						inspect( "RobotsCheck", page( '<meta name="robots" content="noindexing">' ) )
					).toBeEmpty();
				} );

			} );

			describe( "structured data", function(){

				it( "notices a page with none", function(){
					var found = inspect( "StructuredDataCheck", page( "<h1>About</h1>" ) );

					expect( found.len() ).toBe( 1 );
					expect( found[ 1 ].checkId ).toBe( "structuredData.missing" );
					// A notice: structured data earns a rich result, it does
					// not earn a ranking, so its absence is not a fault.
					expect( found[ 1 ].severity ).toBe( "notice" );
				} );

				it( "says nothing about a valid block", function(){
					expect( inspect(
						"StructuredDataCheck",
						page( '<script type="application/ld+json">{"@context":"https://schema.org","@type":"Organization","name":"X"}</script>' )
					) ).toBeEmpty();
				} );

				it( "warns about a block that is not valid JSON", function(){
					// The finding this check exists for. JSON-LD fails
					// silently: the page looks completely normal and the markup
					// somebody spent an afternoon on does nothing.
					var found = inspect(
						"StructuredDataCheck",
						page( '<script type="application/ld+json">{"@type":"Thing",}</script>' )
					);

					expect( found.len() ).toBe( 1 );
					expect( found[ 1 ].checkId ).toBe( "structuredData.invalid" );
					expect( found[ 1 ].severity ).toBe( "warning" );
				} );

				it( "warns about a block with no @type", function(){
					var found = inspect(
						"StructuredDataCheck",
						page( '<script type="application/ld+json">{"name":"X"}</script>' )
					);

					expect( found.len() ).toBe( 1 );
					expect( found[ 1 ].checkId ).toBe( "structuredData.noType" );
				} );

				it( "accepts an array of typed objects", function(){
					expect( inspect(
						"StructuredDataCheck",
						page( '<script type="application/ld+json">[{"@type":"A"},{"@type":"B"}]</script>' )
					) ).toBeEmpty();
				} );

				it( "refuses an array where only some entries are typed", function(){
					// One typed object in a list of three does not make the
					// other two usable.
					var found = inspect(
						"StructuredDataCheck",
						page( '<script type="application/ld+json">[{"@type":"A"},{"name":"B"}]</script>' )
					);

					expect( found.len() ).toBe( 1 );
					expect( found[ 1 ].checkId ).toBe( "structuredData.noType" );
				} );

				it( "looks inside @graph", function(){
					expect( inspect(
						"StructuredDataCheck",
						page( '<script type="application/ld+json">{"@context":"https://schema.org","@graph":[{"@type":"WebSite"}]}</script>' )
					) ).toBeEmpty();
				} );

				it( "accepts a @type that is itself an array", function(){
					expect( inspect(
						"StructuredDataCheck",
						page( '<script type="application/ld+json">{"@type":["Person","Author"],"name":"X"}</script>' )
					) ).toBeEmpty();
				} );

				it( "judges each block separately and says which one is wrong", function(){
					// A layout block plus a page block is normal, so the detail
					// has to name the one at fault.
					var found = inspect(
						"StructuredDataCheck",
						page(
							'<script type="application/ld+json">{"@type":"WebSite"}</script>'
							& '<script type="application/ld+json">not json at all</script>'
						)
					);

					expect( found.len() ).toBe( 1 );
					expect( found[ 1 ].checkId ).toBe( "structuredData.invalid" );
					expect( found[ 1 ].detail ).toInclude( "Block 2 of 2" );
				} );

				it( "ignores a script that is not JSON-LD", function(){
					// An ordinary `<script>` is code, not structured data, and
					// a page with one still has none.
					var found = inspect(
						"StructuredDataCheck",
						page( '<script>var x = {broken:,};</script>' )
					);

					expect( found.len() ).toBe( 1 );
					expect( found[ 1 ].checkId ).toBe( "structuredData.missing" );
				} );

			} );

			describe( "open graph", function(){

				it( "reports missing tags as notices, never louder", function(){
					var found = inspect( "OpenGraphCheck", page( "<title>x</title>" ) );

					expect( found.len() ).toBe( 1 );
					expect( found[ 1 ].severity ).toBe( "notice" );
					expect( found[ 1 ].detail ).toInclude( "og:title" );
				} );

				it( "is satisfied by property attributes, not name attributes", function(){
					var wrong = inspect(
						"OpenGraphCheck",
						page( '<meta name="og:title" content="x"><meta name="og:description" content="y"><meta name="og:image" content="z">' )
					);
					var right = inspect(
						"OpenGraphCheck",
						page( '<meta property="og:title" content="x"><meta property="og:description" content="y"><meta property="og:image" content="z">' )
					);

					expect( wrong.len() ).toBe( 1 );
					expect( right ).toBeEmpty();
				} );

			} );

			describe( "url shape", function(){

				it( "says nothing about the home page, which has no path to judge", function(){
					expect( inspect( "UrlShapeCheck", page( "<p>x</p>" ), { "path" : "" } ) ).toBeEmpty();
				} );

				it( "notices underscores and capitals", function(){
					var ids = inspect(
						"UrlShapeCheck",
						page( "<p>x</p>" ),
						{ "path" : "About_Us/Team" }
					).map( ( f ) => f.checkId );

					expect( ids ).toInclude( "url.underscores" );
					expect( ids ).toInclude( "url.uppercase" );
				} );

				it( "says nothing about a clean path", function(){
					expect(
						inspect( "UrlShapeCheck", page( "<p>x</p>" ), { "path" : "about-us/team" } )
					).toBeEmpty();
				} );

			} );

			describe( "status", function(){

				it( "reports a 404 as an error", function(){
					var found = inspect( "StatusCheck", page( "<p>x</p>" ), { "statusCode" : 404 } );

					expect( found.len() ).toBe( 1 );
					expect( found[ 1 ].checkId ).toBe( "status.error" );
					expect( found[ 1 ].severity ).toBe( "error" );
				} );

				it( "reports a redirect as a warning and names where it goes", function(){
					var found = inspect(
						"StatusCheck",
						page( "" ),
						{ "statusCode" : 301, "location" : "/elsewhere" }
					);

					expect( found[ 1 ].checkId ).toBe( "status.redirect" );
					expect( found[ 1 ].detail ).toInclude( "/elsewhere" );
				} );

				it( "says nothing about a 200 that parsed", function(){
					expect( inspect( "StatusCheck", page( "<p>x</p>" ), { "statusCode" : 200 } ) )
						.toBeEmpty();
				} );

				it( "reports a 200 that could not be parsed, because nothing else could run", function(){
					var found = inspect( "StatusCheck", page( "" ), { "statusCode" : 200 } );

					expect( found.len() ).toBe( 1 );
					expect( found[ 1 ].checkId ).toBe( "status.unparseable" );
				} );

			} );

		} );
	}

	/* --------------------------------------------------------------------- */

	private function page( required string body ){
		return getInstance( "HtmlDocument@seoaudit" ).loadHtml(
			len( arguments.body ) ? "<html><head></head><body>" & arguments.body & "</body></html>" : ""
		);
	}

	private struct function context( struct overrides = {} ){
		var base = {
			"siteId"      : 1,
			"siteName"    : "Test Site",
			"path"        : "about",
			"absoluteUrl" : "https://x.test/about",
			"statusCode"  : 200,
			"location"    : "",
			"fetchError"  : "",
			"elapsedMs"   : 5
		};

		structAppend( base, arguments.overrides, true );

		return base;
	}

	private array function inspect(
		required string check,
		required any document,
		struct overrides = {}
	){
		return getInstance( arguments.check & "@seoaudit" )
			.inspect( arguments.document, context( arguments.overrides ) );
	}

}
