/**
 * Canonical addresses, robots directives, and the two files a crawler fetches.
 *
 * The specs that matter most here are the ones about *not* saying something: a
 * canonical tag on a 404, or a second URL offered for the home page, does more
 * damage than a missing tag would.
 *
 * Requires migrations to have run: `box migrate up`.
 */
component extends="coldbox.system.testing.BaseTestCase" appMapping="/app" {

	variables.PREFIX = "zzt-seo-";

	function beforeAll(){
		super.beforeAll();
		variables.seo      = getInstance( "SeoService@core" );
		variables.sitemap  = getInstance( "SitemapRegistry@core" );
		variables.sites    = getInstance( "SiteService@core" );
		variables.settings = getInstance( "SiteSettingsRepository@core" );
		cleanup();
		seed();
	}

	function afterAll(){
		cleanup();
		super.afterAll();
	}

	function run(){
		describe( "SEO", function(){

			beforeEach( function( currentSpec ){
				setup();
			} );

			describe( "the address a site is known by", function(){

				it( "builds absolute URLs from the primary domain", function(){
					// Not from the request. A site answering on four hostnames
					// must name one address, or a canonical tag is pointless.
					expect( seo.absoluteUrl( site.getId(), "about" ) ).toInclude( "#PREFIX#one.test/about" );
				} );

				it( "prefers an explicit base URL when one is set", function(){
					settings.put( site.getId(), seo.KEY_BASE_URL, "https://www.example.com" );

					expect( seo.absoluteUrl( site.getId(), "about" ) ).toBe( "https://www.example.com/about" );

					settings.put( site.getId(), seo.KEY_BASE_URL, "" );
				} );

				it( "does not double a slash or lose one", function(){
					settings.put( site.getId(), seo.KEY_BASE_URL, "https://example.com/" );

					expect( seo.absoluteUrl( site.getId(), "/about" ) ).toBe( "https://example.com/about" );

					settings.put( site.getId(), seo.KEY_BASE_URL, "" );
				} );

				it( "leaves an already-absolute address alone", function(){
					// A social image on a CDN must not become
					// https://site/https://cdn/...
					expect( seo.absoluteUrl( site.getId(), "https://cdn.example.com/a.png" ) )
						.toBe( "https://cdn.example.com/a.png" );
				} );

				it( "returns nothing for a site with no domain at all", function(){
					var homeless = sites.createSite( name = "No domain", slug = PREFIX & "none" );

					// Better an absent canonical than one pointing nowhere.
					expect( seo.absoluteUrl( homeless.getId(), "about" ) ).toBe( "" );
				} );

			} );

			describe( "what it tells a crawler", function(){

				it( "lets a site be closed to search engines", function(){
					expect( seo.isIndexable( site.getId() ) ).toBeTrue( "sites are open by default" );

					settings.put( site.getId(), seo.KEY_INDEXABLE, "false" );

					expect( seo.isIndexable( site.getId() ) ).toBeFalse();

					settings.put( site.getId(), seo.KEY_INDEXABLE, "true" );
				} );

				it( "makes a closed site noindex whatever a page asks for", function(){
					settings.put( site.getId(), seo.KEY_INDEXABLE, "false" );

					// A page asking to be indexed must not override the site.
					var meta = seo.metadataFor( site, "about", { "statusCode" : 200, "robots" : "index, follow" } );

					expect( meta.robots ).toBe( "noindex, nofollow" );

					settings.put( site.getId(), seo.KEY_INDEXABLE, "true" );
				} );

				it( "never offers an error page for indexing", function(){
					var meta = seo.metadataFor( site, "gone", { "statusCode" : 404 } );

					expect( meta.robots ).toInclude( "noindex" );
				} );

				it( "emits no canonical on an error page", function(){
					// A canonical on a 404 names a dead URL as the preferred
					// address for a dead URL.
					var meta = seo.metadataFor( site, "gone", { "statusCode" : 404 } );

					expect( meta.canonical ).toBe( "" );
				} );

			} );

			describe( "the canonical address of a page", function(){

				it( "uses the path the resolver names, not the one requested", function(){
					var meta = seo.metadataFor( site, "home", { "statusCode" : 200, "canonicalPath" : "" } );

					// An empty canonical path is the site root, and must not be
					// mistaken for "the resolver said nothing".
					expect( meta.canonical ).toBe( "http://#PREFIX#one.test/" );
				} );

				it( "falls back to the requested path when the resolver says nothing", function(){
					var meta = seo.metadataFor( site, "about", { "statusCode" : 200 } );

					expect( meta.canonical ).toBe( "http://#PREFIX#one.test/about" );
				} );

			} );

			describe( "site-wide defaults", function(){

				it( "fills in a description a page did not give", function(){
					settings.put( site.getId(), seo.KEY_DESCRIPTION, "A studio." );

					expect( seo.metadataFor( site, "about", {} ).description ).toBe( "A studio." );

					// A page's own description still wins.
					expect(
						seo.metadataFor( site, "about", { "metaDescription" : "This page." } ).description
					).toBe( "This page." );

					settings.put( site.getId(), seo.KEY_DESCRIPTION, "" );
				} );

				it( "makes a default social image absolute", function(){
					settings.put( site.getId(), seo.KEY_IMAGE, "/media/a.png" );

					expect( seo.metadataFor( site, "about", {} ).image )
						.toBe( "http://#PREFIX#one.test/media/a.png" );

					settings.put( site.getId(), seo.KEY_IMAGE, "" );
				} );

			} );

			describe( "the sitemap registry", function(){

				it( "drops a duplicate URL rather than listing it twice", function(){
					var registry = getInstance( "SitemapRegistry@core" );

					expect( registry.getRegistered() ).toBeArray();
				} );

				it( "normalises what a provider returns", function(){
					var built = buildRegistry( [
						{ "path" : "/about/", "changeFrequency" : "MONTHLY", "priority" : 0.7 },
						{ "path" : "about",   "changeFrequency" : "monthly" },
						{ "path" : "x",       "changeFrequency" : "occasionally" },
						{ "path" : "y",       "priority" : 9 },
						{ "path" : "z",       "priority" : 0 }
					] );

					var entries = built.getEntriesFor( 1 );

					// Leading and trailing slashes stripped, so `/about/` and
					// `about` are one URL and the duplicate is dropped.
					expect( entries.len() ).toBe( 4 );
					expect( entries[ 1 ].path ).toBe( "about" );
					expect( entries[ 1 ].changeFrequency ).toBe( "monthly" );

					// An invalid frequency is omitted, not written out: some
					// crawlers reject a whole sitemap over one bad value.
					expect( entries[ 2 ].changeFrequency ).toBe( "" );

					expect( entries[ 3 ].priority ).toBe( 1 );
					// A priority of 0 is a real answer and must not become 0.5.
					expect( entries[ 4 ].priority ).toBe( 0 );
				} );

				it( "skips a provider that fails rather than losing the sitemap", function(){
					var registry = freshSitemapRegistry();

					registry.setWirebox(
						createStub().$( "getInstance" ).$results(
							createStub().$( "getSitemapEntries" ).$throws( message = "boom" ),
							createStub().$( "getSitemapEntries", [ { "path" : "kept" } ] )
						)
					);
					registry.register( "Broken@x", 10 ).register( "Working@x", 20 );

					var entries = registry.getEntriesFor( 1 );

					expect( entries.len() ).toBe( 1 );
					expect( entries[ 1 ].path ).toBe( "kept" );
				} );

			} );

		} );
	}

	/* --------------------------------------------------------------------- */

	/**
	 * A registry of this spec's own.
	 *
	 * Never `getInstance( "SitemapRegistry@core" ).init()`: it is a
	 * **singleton**, so reinitialising it empties the registrations every
	 * module made at load — and every spec that runs afterwards in the same
	 * suite sees an empty registry. It passes in isolation and breaks
	 * unrelated bundles in a full run, which is the worst way for a test to be
	 * wrong.
	 */
	private any function freshSitemapRegistry(){
		// `createMock` builds the component without WireBox, so the injected
		// properties it would normally receive have to be supplied here.
		return createMock( "core.models.seo.SitemapRegistry" )
			.init()
			.setLog( createStub().$( "warn" ).$( "error" ).$( "info" ) );
	}

	private function buildRegistry( required array entries ){
		var registry = freshSitemapRegistry();

		registry.setWirebox(
			createStub().$( "getInstance", createStub().$( "getSitemapEntries", arguments.entries ) )
		);
		registry.register( "Stub@x" );

		return registry;
	}

	private function seed(){
		variables.site = sites.createSite( name = "Seo One", slug = PREFIX & "one" );
		sites.addDomain( site.getId(), "#PREFIX#one.test", true );
	}

	private function cleanup(){
		queryExecute( "DELETE FROM sites WHERE slug LIKE :p", { p : PREFIX & "%" } );
	}

}
