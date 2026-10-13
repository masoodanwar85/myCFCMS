/**
 * Choosing the address a run fetches through.
 *
 * This is the piece that worked perfectly on a developer's machine and failed
 * on every URL of a live HTTPS site, so it gets its own specs.
 *
 * The failure: the address was built as `http://127.0.0.1:<cgi.server_port>`.
 * On a TLS site `cgi.server_port` is 443, so the run spoke plain HTTP to an
 * SSL-enabled port and Apache answered 400 Bad Request to all 173 URLs. Nothing
 * in the audit was wrong; it simply never reached the site.
 *
 * Requires migrations to have run: `box migrate up`.
 */
component extends="coldbox.system.testing.BaseTestCase" appMapping="/app" {

	variables.PREFIX = "zzt-fetch-";

	function beforeAll(){
		super.beforeAll();

		variables.sites   = getInstance( "SiteService@core" );
		variables.fetcher = getInstance( "PageFetcher@seoaudit" );

		cleanup();

		variables.site = sites.createSite( name = "Fetcher Test", slug = PREFIX & "one" );
		sites.addDomain( site.getId(), "#PREFIX#one.test", true );

		// A site whose domains do not include the host this request arrived on.
		variables.other = sites.createSite( name = "Fetcher Other", slug = PREFIX & "two" );
		sites.addDomain( other.getId(), "#PREFIX#two.test", true );
	}

	function afterAll(){
		cleanup();
		super.afterAll();
	}

	function run(){
		describe( "Choosing a fetch address", function(){

			it( "never sends plain HTTP to a port the site is served over TLS on", function(){
				// The regression this file exists for. Whatever address is
				// chosen, it must not be `http://` pointing at 443.
				var target = fetcher.resolveTarget( site.getId() );

				expect( target.baseUrl ).notToInclude( ":443" );
			} );

			it( "falls back to loopback, naming the site, when the request host is not the site's", function(){
				// A developer's machine: the admin is reached on 127.0.0.1 and
				// `zzt-fetch-one.test` does not resolve in DNS, so the only way
				// to reach the right tenant is to say which one it is.
				var target = fetcher.resolveTarget( site.getId() );

				expect( target.baseUrl ).toStartWith( "http://127.0.0.1" );
				expect( target.hostHeader ).toBe( "#PREFIX#one.test" );
			} );

			it( "names the right site when two sites could be reached the same way", function(){
				var first  = fetcher.resolveTarget( site.getId() );
				var second = fetcher.resolveTarget( other.getId() );

				expect( first.hostHeader ).notToBe( second.hostHeader );
				expect( second.hostHeader ).toBe( "#PREFIX#two.test" );
			} );

			it( "reports no address at all for a site with no domain", function(){
				// Rather than inventing one and reporting every page as broken.
				var domainless = sites.createSite( name = "No Domain", slug = PREFIX & "three" );
				var target     = fetcher.resolveTarget( domainless.getId() );

				expect( target.baseUrl ).toBe( "" );

				// And a fetch through it fails as data, not as an exception.
				var result = fetcher.fetch( domainless.getId(), "about" );

				expect( result.statusCode ).toBe( 0 );
				expect( result.error ).toInclude( "fetchBaseUrl" );
			} );

			it( "builds a canonical comparison URL from the primary domain, not the fetch address", function(){
				// The address the run happens to fetch through is an
				// implementation detail, and no canonical should ever name it.
				var url = fetcher.publicUrl( site.getId(), "about" );

				expect( url ).toInclude( "#PREFIX#one.test/about" );
				expect( url ).notToInclude( "127.0.0.1" );
			} );

			it( "treats the site root as a path of its own", function(){
				expect( fetcher.publicUrl( site.getId(), "" ) ).toEndWith( "/" );
			} );

		} );

		describe( "Fetching", function(){

			it( "reaches the site and brings back markup", function(){
				var target = fetcher.resolveTarget( site.getId() );
				var result = fetcher.fetch( site.getId(), "", target.baseUrl, target.hostHeader );

				expect( result.statusCode ).toBeGT( 0, "no response: " & result.error );
				expect( result.elapsedMs ).toBeGTE( 0 );
			} );

			it( "returns a failure as data rather than throwing", function(){
				// A run must survive one unreachable URL and carry on.
				var result = fetcher.fetch( site.getId(), "about", "http://127.0.0.1:1", "x.test" );

				expect( result.statusCode ).toBe( 0 );
				expect( result.error ).notToBeEmpty();
			} );

			it( "does not follow redirects, because a redirect is a finding", function(){
				// `redirect = false` is what lets StatusCheck see a 301 at all.
				var target = fetcher.resolveTarget( site.getId() );
				var result = fetcher.fetch( site.getId(), "", target.baseUrl, target.hostHeader );

				expect( result ).toHaveKey( "location" );
			} );

		} );
	}

	private function cleanup(){
		queryExecute( "DELETE FROM sites WHERE slug LIKE :p", { p : PREFIX & "%" } );
	}

}
