/**
 * The practice's own details, as a theme reads them.
 *
 * Two things are worth testing here and the rest is plumbing. **Validation
 * runs twice** — on the way in and again on the way out — because a row can
 * reach `site_settings` from a migration, a seed or a direct `UPDATE`, and a
 * value that would be refused today must not be rendered into a `tel:` href
 * just because it is already stored. And **a save is all-or-nothing**, so a
 * bad phone number does not leave half the form applied.
 *
 * Requires migrations to have run: `box migrate up`.
 */
component extends="coldbox.system.testing.BaseTestCase" appMapping="/app" {

	variables.PREFIX = "zzt-firm-";

	function beforeAll(){
		super.beforeAll();

		variables.sites    = getInstance( "SiteService@core" );
		variables.settings = getInstance( "SiteSettingsRepository@core" );
		variables.firm     = getInstance( "FirmDetailsService@core" );

		cleanup();
		variables.site = sites.createSite( name = "Firm details", slug = PREFIX & "one" );
	}

	function afterAll(){
		cleanup();
		super.afterAll();
	}

	function run(){
		describe( "Firm details", function(){

			beforeEach( function( currentSpec ){
				setup();
				// Each spec starts from nothing stored, so none of them depends
				// on the order they run in.
				for ( var field in firm.getFields() ) {
					settings.put( site.getId(), "firm." & field.key, "" );
				}
			} );

			describe( "reading", function(){

				it( "answers every field as an empty string before anything is set", function(){
					// A theme writes `args.firm.phone` with no guard, so every
					// key has to exist from the first render.
					var details = firm.firmFor( site.getId() );

					for ( var field in firm.getFields() ) {
						expect( details ).toHaveKey( field.key );
						expect( details[ field.key ] ).toBe( "" );
					}
				} );

				it( "reads back what was saved", function(){
					firm.save( site.getId(), { phone : "02 9000 1234", hours : "Mon to Fri, 9 to 5" } );

					var details = firm.firmFor( site.getId() );

					expect( details.phone ).toBe( "02 9000 1234" );
					expect( details.hours ).toBe( "Mon to Fri, 9 to 5" );
				} );

				it( "says whether a value is worth rendering", function(){
					firm.save( site.getId(), { phone : "02 9000 1234" } );

					var details = firm.firmFor( site.getId() );

					expect( firm.hasValue( details, "phone" ) ).toBeTrue();
					expect( firm.hasValue( details, "email" ) ).toBeFalse();
				} );

				it( "treats a key it has never heard of as absent rather than throwing", function(){
					// A theme asking for a field that was renamed should drop
					// the element, not take the page down.
					expect( firm.hasValue( firm.firmFor( site.getId() ), "nosuchfield" ) ).toBeFalse();
				} );

			} );

			describe( "the second gate, on the way out", function(){

				it( "drops a stored phone number that would not be accepted today", function(){
					// Written straight to the repository, which is exactly how a
					// migration or a hand-run UPDATE would do it.
					settings.put( site.getId(), "firm.phone", "javascript:alert(1)" );

					expect( firm.firmFor( site.getId() ).phone ).toBe(
						"",
						"a stored value that fails validation must not reach a tel: href"
					);
				} );

				it( "drops a stored email that is not an address", function(){
					settings.put( site.getId(), "firm.email", "nope"" onmouseover=""alert(1)" );

					expect( firm.firmFor( site.getId() ).email ).toBe( "" );
				} );

				it( "still shows the bad value in the settings form, and flags it", function(){
					// Blanking the field is how somebody loses a value without
					// being told. The form shows it and says it is not in use.
					settings.put( site.getId(), "firm.phone", "ring us" );

					var row = rowFor( "phone" );

					expect( row.value ).toBe( "ring us" );
					expect( row.valid ).toBeFalse();
				} );

				it( "leaves a good value alone in both places", function(){
					firm.save( site.getId(), { phone : "+61 2 9000 1234" } );

					var row = rowFor( "phone" );

					expect( row.valid ).toBeTrue();
					expect( firm.firmFor( site.getId() ).phone ).toBe( "+61 2 9000 1234" );
				} );

			} );

			describe( "validation", function(){

				it( "accepts the punctuation a printed number uses", function(){
					for ( var number in [ "02 9000 1234", "+61 2 9000 1234", "(02) 9000-1234", "1300 000 000" ] ) {
						expect( firm.isValidPhone( number ) ).toBeTrue( "should accept #number#" );
					}
				} );

				it( "refuses letters in a phone number, because it becomes a link", function(){
					for ( var number in [ "javascript:alert(1)", "call us", "02 9000 1234 ext two" ] ) {
						expect( firm.isValidPhone( number ) ).toBeFalse( "should refuse #number#" );
					}
				} );

				it( "refuses an address that is not one", function(){
					for ( var address in [ "not an email", "a@b", "a b@c.com", "@example.com" ] ) {
						expect( firm.isValidEmail( address ) ).toBeFalse( "should refuse #address#" );
					}
				} );

				it( "accepts an ordinary address", function(){
					expect( firm.isValidEmail( "enquiries@probate-services.com.au" ) ).toBeTrue();
				} );

				it( "refuses a bad phone number on save, with a message a person can act on", function(){
					expect( function(){
						firm.save( site.getId(), { phone : "ring us" } );
					} ).toThrow( type = "Firm.InvalidPhone" );
				} );

				it( "refuses a bad email on save", function(){
					expect( function(){
						firm.save( site.getId(), { email : "nope" } );
					} ).toThrow( type = "Firm.InvalidEmail" );
				} );

				it( "refuses a single-line field that is too long", function(){
					expect( function(){
						firm.save( site.getId(), { hours : repeatString( "x", 201 ) } );
					} ).toThrow( type = "Firm.TooLong" );
				} );

				it( "allows a longer value in a field meant for several lines", function(){
					expect( function(){
						firm.save( site.getId(), { feeApproach : repeatString( "x", 400 ) } );
					} ).notToThrow();
				} );

			} );

			describe( "saving", function(){

				it( "stores nothing at all when one field is invalid", function(){
					// All-or-nothing: a partially applied form is harder to
					// notice than a refused one.
					firm.save( site.getId(), { hours : "Mon to Fri" } );

					try {
						firm.save( site.getId(), { hours : "Weekends too", phone : "ring us" } );
					} catch ( Firm.InvalidPhone e ) {
						// expected
					}

					expect( firm.firmFor( site.getId() ).hours ).toBe(
						"Mon to Fri",
						"the valid field was written even though the save failed"
					);
				} );

				it( "leaves a field alone when the form did not mention it", function(){
					// What lets one screen save a subset without blanking the rest.
					firm.save( site.getId(), { phone : "02 9000 1234", hours : "Mon to Fri" } );
					firm.save( site.getId(), { hours : "Mon to Sat" } );

					expect( firm.firmFor( site.getId() ).phone ).toBe( "02 9000 1234" );
					expect( firm.firmFor( site.getId() ).hours ).toBe( "Mon to Sat" );
				} );

				it( "clears a field that was submitted empty", function(){
					// Present and empty means "remove it", which is different
					// from absent. That is how a field gets cleared at all.
					firm.save( site.getId(), { phone : "02 9000 1234" } );
					firm.save( site.getId(), { phone : "" } );

					expect( firm.firmFor( site.getId() ).phone ).toBe( "" );
				} );

				it( "ignores keys that are not fields", function(){
					// The handler passes the whole request collection, which
					// carries csrfToken, event and the rest.
					firm.save( site.getId(), { phone : "02 9000 1234", csrfToken : "abc", event : "x" } );

					expect( firm.firmFor( site.getId() ).phone ).toBe( "02 9000 1234" );
					expect( settings.getValue( site.getId(), "firm.csrfToken", "" ) ).toBe( "" );
				} );

				it( "trims what it stores", function(){
					firm.save( site.getId(), { hours : "   Mon to Fri   " } );

					expect( firm.firmFor( site.getId() ).hours ).toBe( "Mon to Fri" );
				} );

			} );

			describe( "one site's details are its own", function(){

				it( "does not leak between sites", function(){
					var other = sites.createSite( name = "Other firm", slug = PREFIX & "two" );

					firm.save( site.getId(), { phone : "02 9000 1234" } );

					expect( firm.firmFor( other.getId() ).phone ).toBe( "" );
				} );

			} );

		} );
	}

	/**
	 * One field's row from the settings projection.
	 *
	 * Assigned out of the filter rather than chained: ACF will not accept a
	 * member call on the result of one in every position.
	 */
	private struct function rowFor( required string key ){
		var wanted = arguments.key;
		var rows   = firm.settingsFor( site.getId() ).filter( function( field ){
			return field.key == wanted;
		} );

		expect( rows.len() ).toBe( 1, "no field called #wanted#" );

		return rows[ 1 ];
	}

	private function cleanup(){
		queryExecute( "DELETE FROM sites WHERE slug LIKE :p", { p : PREFIX & "%" } );
	}

}
