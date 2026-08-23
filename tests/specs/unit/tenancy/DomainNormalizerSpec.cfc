/**
 * Normalisation is the contract between what an administrator types and what
 * arrives in a `Host` header. If these two ever disagree, a live site stops
 * resolving, so the rules are pinned down here.
 */
component extends="coldbox.system.testing.BaseTestCase" appMapping="/app" {

	function beforeAll(){
		super.beforeAll();
		variables.normalizer = getInstance( "DomainNormalizer@core" );
	}

	function afterAll(){
		super.afterAll();
	}

	function run(){
		describe( "DomainNormalizer", function(){

			it( "lower-cases the host", function(){
				expect( normalizer.normalize( "Client.COM" ) ).toBe( "client.com" );
			} );

			it( "trims surrounding whitespace", function(){
				expect( normalizer.normalize( "  client.com  " ) ).toBe( "client.com" );
			} );

			it( "strips the port", function(){
				expect( normalizer.normalize( "client.com:8080" ) ).toBe( "client.com" );
			} );

			it( "strips a scheme and path", function(){
				expect( normalizer.normalize( "https://client.com/about?x=1" ) ).toBe( "client.com" );
			} );

			it( "strips a trailing root dot", function(){
				expect( normalizer.normalize( "client.com." ) ).toBe( "client.com" );
			} );

			it( "keeps the www prefix, because it is a separate domain row", function(){
				expect( normalizer.normalize( "WWW.Client.com" ) ).toBe( "www.client.com" );
			} );

			it( "keeps subdomains intact", function(){
				expect( normalizer.normalize( "staging.client.co.uk" ) ).toBe( "staging.client.co.uk" );
			} );

			it( "returns an empty string for empty or missing input", function(){
				expect( normalizer.normalize( "" ) ).toBe( "" );
				expect( normalizer.normalize() ).toBe( "" );
				expect( normalizer.normalize( "   " ) ).toBe( "" );
			} );

			it( "rejects structurally invalid hosts", function(){
				expect( normalizer.normalize( "not a domain" ) ).toBe( "" );
				expect( normalizer.normalize( "-leading-hyphen.com" ) ).toBe( "" );
				expect( normalizer.normalize( "trailing-hyphen-.com" ) ).toBe( "" );
			} );

			it( "accepts localhost and IPv4 literals for local development", function(){
				expect( normalizer.normalize( "localhost:8080" ) ).toBe( "localhost" );
				expect( normalizer.normalize( "127.0.0.1:3000" ) ).toBe( "127.0.0.1" );
			} );

			it( "is idempotent", function(){
				var once  = normalizer.normalize( "HTTPS://WWW.Client.com:443/path" );
				var twice = normalizer.normalize( once );
				expect( twice ).toBe( once );
				expect( twice ).toBe( "www.client.com" );
			} );

		} );
	}

}
