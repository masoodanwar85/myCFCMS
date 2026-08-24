/**
 * The tenant-scoped key/value store, against a real database.
 *
 * Mostly one regression. Site settings are strings, and for a long time nothing
 * stored a string that CFML considers falsy — so the fact that `"false"` and
 * `"0"` came back as `""` went unnoticed until the first boolean setting
 * arrived and could not be turned off.
 *
 * Requires migrations to have run: `box migrate up`.
 */
component extends="coldbox.system.testing.BaseTestCase" appMapping="/app" {

	variables.PREFIX = "zzt-ss-";

	function beforeAll(){
		super.beforeAll();
		variables.repo  = getInstance( "SiteSettingsRepository@core" );
		variables.sites = getInstance( "SiteService@core" );
		cleanup();
		variables.site = sites.createSite( name = "Settings One", slug = PREFIX & "one" );
	}

	function afterAll(){
		cleanup();
		super.afterAll();
	}

	function run(){
		describe( "SiteSettingsRepository", function(){

			it( "stores and returns a plain value", function(){
				repo.put( site.getId(), "probe.text", "hello" );

				expect( repo.getValue( site.getId(), "probe.text", "MISSING" ) ).toBe( "hello" );
			} );

			it( "returns the default when a key was never set", function(){
				expect( repo.getValue( site.getId(), "probe.never", "MISSING" ) ).toBe( "MISSING" );
			} );

			/**
			 * The bug. `getSettingValue() ?: ""` looks like a null guard and is
			 * not: ColdFusion's elvis operator falls through on any falsy value.
			 */
			it( "keeps values ColdFusion considers falsy", function(){
				for ( var value in [ "false", "0", "no", "off" ] ) {
					repo.put( site.getId(), "probe.falsy", value );

					expect( repo.getValue( site.getId(), "probe.falsy", "MISSING" ) ).toBe(
						value,
						"[#value#] must survive a round trip; it is a value, not an absence"
					);
				}
			} );

			it( "keeps falsy values when read in bulk", function(){
				repo.put( site.getId(), "probe.bulk", "false" );

				var all = repo.getAllForSite( site.getId() );

				expect( all ).toHaveKey( "probe.bulk" );
				expect( all[ "probe.bulk" ] ).toBe( "false" );
			} );

			it( "overwrites rather than duplicating a key", function(){
				repo.put( site.getId(), "probe.once", "first" );
				repo.put( site.getId(), "probe.once", "second" );

				expect( repo.getValue( site.getId(), "probe.once" ) ).toBe( "second" );
			} );

			it( "scopes a key to one site", function(){
				var other = sites.createSite( name = "Settings Two", slug = PREFIX & "two" );

				repo.put( site.getId(), "probe.scoped", "mine" );

				expect( repo.getValue( other.getId(), "probe.scoped", "MISSING" ) ).toBe( "MISSING" );
			} );

		} );
	}

	private function cleanup(){
		queryExecute( "DELETE FROM sites WHERE slug LIKE :p", { p : PREFIX & "%" } );
	}

}
