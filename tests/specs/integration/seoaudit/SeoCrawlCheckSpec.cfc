/**
 * Checks that need the whole crawl.
 *
 * These are the findings a per-page check cannot produce, so each spec here is
 * about the *set*: two pages sharing a title, a link whose target the crawl saw
 * fail, a page the sitemap advertises that nothing links to.
 *
 * As with the per-page checks, the assertions about what must *not* be reported
 * matter as much as the rest. A crawl check fires once per page in a group, so
 * a false positive multiplies.
 *
 * Requires migrations to have run: `box migrate up`.
 */
component extends="coldbox.system.testing.BaseTestCase" appMapping="/app" {

	function beforeAll(){
		super.beforeAll();
		variables.registry = getInstance( "SeoCrawlCheckRegistry@seoaudit" );
	}

	function run(){
		describe( "Crawl-wide checks", function(){

			describe( "the registry", function(){

				it( "has the crawl checks registered", function(){
					var ids = registry.getRegistered();

					for ( var check in [ "BrokenLinkCheck", "DuplicateContentCheck", "SitemapReconciliationCheck" ] ) {
						expect( ids ).toInclude( check & "@seoaudit" );
					}
				} );

			} );

			describe( "broken links", function(){

				it( "reports a link against the page that contains it", function(){
					// Not against the missing page: that page does not exist,
					// so there would be nothing to open and fix.
					var found = inspect( "BrokenLinkCheck", [
						page( path = "about", links = [ "gone" ] ),
						page( path = "gone", statusCode = 404 )
					] );

					var broken = found.filter( ( f ) => f.checkId == "link.broken" );

					expect( broken.len() ).toBe( 1 );
					expect( broken[ 1 ].path ).toBe( "about" );
					expect( broken[ 1 ].severity ).toBe( "error" );
					expect( broken[ 1 ].detail ).toInclude( "/gone" );
					expect( broken[ 1 ].detail ).toInclude( "404" );
				} );

				it( "reports a link through a redirect as a notice", function(){
					var found = inspect( "BrokenLinkCheck", [
						page( path = "about", links = [ "moved" ] ),
						page( path = "moved", statusCode = 301 )
					] );

					var redirects = found.filter( ( f ) => f.checkId == "link.redirect" );

					expect( redirects.len() ).toBe( 1 );
					expect( redirects[ 1 ].severity ).toBe( "notice" );
				} );

				it( "says nothing about a link whose target the crawl never reached", function(){
					// Unknown is not broken. A run bounded by maxUrls would
					// otherwise report hundreds of findings that say only
					// "the audit ran out of budget".
					var found = inspect( "BrokenLinkCheck", [
						page( path = "about", links = [ "never-fetched" ] )
					] );

					expect( found ).toBeEmpty();
				} );

				it( "says nothing about links on a page that itself failed", function(){
					// Its own failure is already reported by StatusCheck, and
					// a 404 page's markup is not the site's content.
					var found = inspect( "BrokenLinkCheck", [
						page( path = "broken", statusCode = 500, links = [ "gone" ] ),
						page( path = "gone", statusCode = 404 )
					] );

					expect( found ).toBeEmpty();
				} );

				it( "says nothing when every link works", function(){
					var found = inspect( "BrokenLinkCheck", [
						page( path = "", links = [ "about" ] ),
						page( path = "about", links = [ "" ] )
					] );

					expect( found ).toBeEmpty();
				} );

			} );

			describe( "duplicate titles and descriptions", function(){

				it( "reports a shared title on every page in the group", function(){
					// There is no basis for calling any one of them the
					// duplicate, and whoever fixes it needs all the addresses.
					var found = inspect( "DuplicateContentCheck", [
						page( path = "a", title = "Our services" ),
						page( path = "b", title = "Our services" ),
						page( path = "c", title = "Something else" )
					] ).filter( ( f ) => f.checkId == "duplicate.title" );

					expect( found.len() ).toBe( 2 );
					expect( found.map( ( f ) => f.path ).sort( "text" ) ).toBe( [ "a", "b" ] );
				} );

				it( "names the other pages but not the one being reported", function(){
					var found = inspect( "DuplicateContentCheck", [
						page( path = "a", title = "Our services" ),
						page( path = "b", title = "Our services" )
					] ).filter( ( f ) => f.checkId == "duplicate.title" && f.path == "a" );

					expect( found[ 1 ].detail ).toInclude( "/b" );
					expect( found[ 1 ].detail ).notToInclude( "/a" );
				} );

				it( "treats titles differing only in case or spacing as the same", function(){
					// They are the same title to a reader and to a search
					// engine, so reporting them as distinct would miss it.
					var found = inspect( "DuplicateContentCheck", [
						page( path = "a", title = "Our Services" ),
						page( path = "b", title = "our   services" )
					] ).filter( ( f ) => f.checkId == "duplicate.title" );

					expect( found.len() ).toBe( 2 );
				} );

				it( "ranks a duplicate title above a duplicate description", function(){
					// A shared title dilutes ranking; a shared description only
					// looks repetitive, and is often rewritten anyway.
					var found = inspect( "DuplicateContentCheck", [
						page( path = "a", title = "Same", description = "Same words here" ),
						page( path = "b", title = "Same", description = "Same words here" )
					] );

					var titles = found.filter( ( f ) => f.checkId == "duplicate.title" );
					var descriptions = found.filter( ( f ) => f.checkId == "duplicate.description" );

					expect( titles[ 1 ].severity ).toBe( "warning" );
					expect( descriptions[ 1 ].severity ).toBe( "notice" );
				} );

				it( "does not group pages that simply have no title", function(){
					// "Nine pages share the same blank title" is true and
					// useless; the missing title is reported per page already.
					var found = inspect( "DuplicateContentCheck", [
						page( path = "a", title = "" ),
						page( path = "b", title = "" )
					] );

					expect( found ).toBeEmpty();
				} );

				it( "says nothing when every title is distinct", function(){
					var found = inspect( "DuplicateContentCheck", [
						page( path = "a", title = "One", description = "First page" ),
						page( path = "b", title = "Two", description = "Second page" )
					] );

					expect( found ).toBeEmpty();
				} );

			} );

			describe( "sitemap reconciliation", function(){

				it( "reports a page the sitemap advertises that nothing links to", function(){
					var found = inspect( "SitemapReconciliationCheck", [
						page( path = "", seeded = true, links = [ "about" ] ),
						page( path = "about", seeded = true ),
						page( path = "forgotten", seeded = true )
					] ).filter( ( f ) => f.checkId == "sitemap.orphan" );

					expect( found.len() ).toBe( 1 );
					expect( found[ 1 ].path ).toBe( "forgotten" );
					expect( found[ 1 ].severity ).toBe( "warning" );
				} );

				it( "never calls the home page an orphan", function(){
					// It is what the bare domain serves, so it is reachable by
					// definition whether or not anything links to it.
					var found = inspect( "SitemapReconciliationCheck", [
						page( path = "", seeded = true )
					] ).filter( ( f ) => f.checkId == "sitemap.orphan" );

					expect( found ).toBeEmpty();
				} );

				it( "notices a linked page that is not in the sitemap, and allows that it may be deliberate", function(){
					var found = inspect( "SitemapReconciliationCheck", [
						page( path = "", seeded = true, links = [ "thank-you" ] ),
						page( path = "thank-you", seeded = false )
					] ).filter( ( f ) => f.checkId == "sitemap.missing" );

					expect( found.len() ).toBe( 1 );
					expect( found[ 1 ].severity ).toBe( "notice" );
					expect( found[ 1 ].message ).toInclude( "may be deliberate" );
				} );

				it( "says nothing when the sitemap and the links agree", function(){
					var found = inspect( "SitemapReconciliationCheck", [
						page( path = "", seeded = true, links = [ "about" ] ),
						page( path = "about", seeded = true, links = [ "" ] )
					] );

					expect( found ).toBeEmpty();
				} );

			} );

		} );
	}

	/* --------------------------------------------------------------------- */

	private struct function page(
		required string path,
		numeric statusCode = 200,
		string title       = "A reasonable page title here",
		string description = "",
		string canonical   = "",
		array links        = [],
		boolean seeded     = true
	){
		return {
			"path"        : arguments.path,
			"statusCode"  : arguments.statusCode,
			"title"       : arguments.title,
			"description" : arguments.description,
			"canonical"   : arguments.canonical,
			"links"       : arguments.links,
			"seeded"      : arguments.seeded
		};
	}

	private array function inspect( required string check, required array pages ){
		return getInstance( arguments.check & "@seoaudit" )
			.inspect( arguments.pages, { "siteId" : 1, "siteName" : "Test Site" } );
	}

}
