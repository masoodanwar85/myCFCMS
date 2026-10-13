/**
 * Deciding which URLs a run looks at.
 *
 * The link filter is where a crawl goes wrong quietly: follow too much and the
 * budget goes on PDFs and other people's websites, follow too little and the
 * audit misses half the site and reports a confident total anyway.
 *
 * Requires migrations to have run: `box migrate up`.
 */
component extends="coldbox.system.testing.BaseTestCase" appMapping="/app" {

	function beforeAll(){
		super.beforeAll();
		variables.discovery = getInstance( "UrlDiscovery@seoaudit" );
		variables.hosts     = [ "example.test", "www.example.test" ];
	}

	function run(){
		describe( "UrlDiscovery", function(){

			describe( "what counts as an auditable path", function(){

				it( "audits the home page, which has no path at all", function(){
					expect( discovery.isAuditable( "" ) ).toBeTrue();
					expect( discovery.isAuditable( "/" ) ).toBeTrue();
				} );

				it( "audits ordinary page paths", function(){
					for ( var path in [ "about", "about/team", "services/wills/online" ] ) {
						expect( discovery.isAuditable( path ) ).toBeTrue( path );
					}
				} );

				it( "refuses served files, whatever they are", function(){
					// Fetching a 20MB PDF to look at its title would spend the
					// run's budget on something with no title.
					for ( var path in [
						"media/2026/10/terms.pdf", "assets/app.css", "assets/app.js",
						"photo.png", "data.json", "sitemap.xml", "feed.rss"
					] ) {
						expect( discovery.isAuditable( path ) ).toBeFalse( path );
					}
				} );

				it( "refuses the admin", function(){
					expect( discovery.isAuditable( "admin" ) ).toBeFalse();
					expect( discovery.isAuditable( "admin/pages/edit/4" ) ).toBeFalse();
				} );

				it( "does not mistake a dot in a path segment for an extension", function(){
					// `listLast` with no delimiter present returns the whole
					// string, so a naive extension check treats every path as
					// having one.
					expect( discovery.isAuditable( "about-us" ) ).toBeTrue();
					expect( discovery.isAuditable( "v1.2-release-notes" ) ).toBeTrue();
				} );

			} );

			describe( "turning a link into a path", function(){

				it( "accepts a root-relative link", function(){
					expect( path( "/about" ) ).toBe( "about" );
					expect( path( "/about/team/" ) ).toBe( "about/team" );
				} );

				it( "accepts an absolute link to this site", function(){
					expect( path( "https://example.test/about" ) ).toBe( "about" );
					expect( path( "http://www.example.test/about" ) ).toBe( "about" );
				} );

				it( "returns the home page as an empty path, not as nothing", function(){
					// The distinction the whole null contract exists for: "" is
					// the home page, null is "not a link worth auditing".
					var home = discovery.pathFromLink( "/", hosts );

					expect( isNull( home ) ).toBeFalse();
					expect( home ).toBe( "" );
				} );

				it( "refuses another site", function(){
					expect( isNull( discovery.pathFromLink( "https://google.com/x", hosts ) ) ).toBeTrue();
					expect( isNull( discovery.pathFromLink( "//cdn.other.test/a", hosts ) ) ).toBeTrue();
				} );

				it( "refuses things that are not pages", function(){
					for ( var href in [
						"##top", "mailto:a@b.test", "tel:+61400000000",
						"javascript:void(0)", "data:text/html,x", ""
					] ) {
						expect( isNull( discovery.pathFromLink( href, hosts ) ) )
							.toBeTrue( "should have refused: " & href );
					}
				} );

				it( "strips a fragment and a query, which name the same document", function(){
					expect( path( "/about##team" ) ).toBe( "about" );
					expect( path( "/about?utm_source=x" ) ).toBe( "about" );
					expect( path( "/about?a=1##b" ) ).toBe( "about" );
				} );

				it( "refuses a file link even when it is on this site", function(){
					expect( isNull( discovery.pathFromLink( "/media/2026/10/terms.pdf", hosts ) ) ).toBeTrue();
					expect( isNull( discovery.pathFromLink( "https://example.test/a.png", hosts ) ) ).toBeTrue();
				} );

				it( "skips a relative link rather than guessing where it points", function(){
					// This CMS emits absolute paths. Resolving `../x` would mean
					// inventing a base, and inventing one wrongly would audit a
					// URL that does not exist.
					expect( isNull( discovery.pathFromLink( "team", hosts ) ) ).toBeTrue();
					expect( isNull( discovery.pathFromLink( "../team", hosts ) ) ).toBeTrue();
				} );

			} );

		} );
	}

	/* --------------------------------------------------------------------- */

	private string function path( required string href ){
		var result = discovery.pathFromLink( arguments.href, variables.hosts );

		return isNull( result ) ? "(null)" : result;
	}

}
