/**
 * Slugs are permanent once a URL is published, so getting a title wrong here is
 * expensive to undo.
 */
component extends="coldbox.system.testing.BaseTestCase" appMapping="/app" {

	function beforeAll(){
		super.beforeAll();
		variables.slugs = getInstance( "Slugifier@core" );
	}

	function afterAll(){
		super.afterAll();
	}

	function run(){
		describe( "Slugifier", function(){

			it( "lower-cases and hyphenates", function(){
				expect( slugs.slugify( "About Our Team" ) ).toBe( "about-our-team" );
			} );

			it( "collapses runs of separators", function(){
				expect( slugs.slugify( "  Spaced   Out  " ) ).toBe( "spaced-out" );
				expect( slugs.slugify( "a -- b" ) ).toBe( "a-b" );
			} );

			it( "transliterates accents rather than dropping them", function(){
				// The old behaviour turned this into "caf-nster".
				expect( slugs.slugify( "Café Münster" ) ).toBe( "cafe-muenster" );
				expect( slugs.slugify( "Crème Brûlée" ) ).toBe( "creme-brulee" );
				expect( slugs.slugify( "Piñata Niño" ) ).toBe( "pinata-nino" );
			} );

			it( "follows German convention for umlauts and sharp s", function(){
				expect( slugs.slugify( "Zürich Straße" ) ).toBe( "zuerich-strasse" );
			} );

			it( "handles Nordic and Polish letters", function(){
				expect( slugs.slugify( "Årsrapport Øst" ) ).toBe( "arsrapport-ost" );
				expect( slugs.slugify( "Łódź" ) ).toBe( "lodz" );
			} );

			it( "spells out an ampersand", function(){
				expect( slugs.slugify( "Team & Friends" ) ).toBe( "team-and-friends" );
			} );

			it( "returns empty when nothing usable survives", function(){
				expect( slugs.slugify( "!!!" ) ).toBe( "" );
				expect( slugs.slugify( "" ) ).toBe( "" );
				expect( slugs.slugify() ).toBe( "" );
			} );

			it( "is idempotent", function(){
				var once = slugs.slugify( "Café Münster" );

				expect( slugs.slugify( once ) ).toBe( once );
			} );

			it( "is the single implementation every service uses", function(){
				// Five copies had drifted; a title must slug identically
				// wherever it is entered.
				var expected = "cafe-muenster";

				for ( var service in [
					"SiteService@core", "RoleService@core",
					"PageService@pages", "BlogService@blog", "ContactService@contact"
				] ) {
					expect( getInstance( service ).slugify( "Café Münster" ) ).toBe( expected );
				}
			} );

		} );
	}

}
