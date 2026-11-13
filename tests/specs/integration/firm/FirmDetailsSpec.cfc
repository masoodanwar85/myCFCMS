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
					firm.save( site.getId(), { phone : "02 9000 1234", abn : "11 222 333 444" } );

					var details = firm.firmFor( site.getId() );

					expect( details.phone ).toBe( "02 9000 1234" );
					expect( details.abn ).toBe( "11 222 333 444" );
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
						firm.save( site.getId(), { trustLine : repeatString( "x", 201 ) } );
					} ).toThrow( type = "Firm.TooLong" );
				} );

				it( "allows a longer value in a field meant for several lines", function(){
					expect( function(){
						firm.save( site.getId(), { address : repeatString( "x", 400 ) } );
					} ).notToThrow();
				} );

			} );

			describe( "saving", function(){

				it( "stores nothing at all when one field is invalid", function(){
					// All-or-nothing: a partially applied form is harder to
					// notice than a refused one.
					firm.save( site.getId(), { trustLine : "Since 1994" } );

					try {
						firm.save( site.getId(), { trustLine : "Since 1995", phone : "ring us" } );
					} catch ( Firm.InvalidPhone e ) {
						// expected
					}

					expect( firm.firmFor( site.getId() ).trustLine ).toBe(
						"Since 1994",
						"the valid field was written even though the save failed"
					);
				} );

				it( "leaves a field alone when the form did not mention it", function(){
					// What lets one screen save a subset without blanking the rest.
					firm.save( site.getId(), { phone : "02 9000 1234", trustLine : "Since 1994" } );
					firm.save( site.getId(), { trustLine : "Since 1995" } );

					expect( firm.firmFor( site.getId() ).phone ).toBe( "02 9000 1234" );
					expect( firm.firmFor( site.getId() ).trustLine ).toBe( "Since 1995" );
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
					firm.save( site.getId(), { trustLine : "   Since 1994   " } );

					expect( firm.firmFor( site.getId() ).trustLine ).toBe( "Since 1994" );
				} );

			} );

			describe( "social profiles", function(){

				it( "accepts an http(s) address", function(){
					expect( firm.isValidUrl( "https://www.facebook.com/yourfirm" ) ).toBeTrue();
					expect( firm.isValidUrl( "http://x.com/yourfirm" ) ).toBeTrue();
				} );

				it( "refuses anything that is not one, because it becomes an href", function(){
					for ( var bad in [
						"javascript:alert(1)",
						"www.facebook.com/yourfirm",
						"//evil.test",
						"data:text/html;base64,x",
						"https://x.test"" onclick=""alert(1)"
					] ) {
						expect( firm.isValidUrl( bad ) ).toBeFalse( "should refuse #bad#" );
					}
				} );

				it( "refuses a bad address on save", function(){
					expect( function(){
						firm.save( site.getId(), { facebook : "not-a-url" } );
					} ).toThrow( type = "Firm.InvalidUrl" );
				} );

				it( "lists only the profiles that are set, in field order", function(){
					// A theme loops the result and draws nothing when it is
					// empty, rather than testing seven keys itself.
					firm.save( site.getId(), {
						linkedin : "https://www.linkedin.com/company/yourfirm",
						facebook : "https://www.facebook.com/yourfirm"
					} );

					var socials = firm.socialsFor( site.getId() );

					expect( socials.len() ).toBe( 2 );
					// Facebook is declared before LinkedIn, and that is the
					// order a theme renders them in.
					expect( socials[ 1 ].key ).toBe( "facebook" );
					expect( socials[ 2 ].key ).toBe( "linkedin" );
					expect( socials[ 1 ].label ).toBe( "Facebook" );
					expect( socials[ 1 ].url ).toBe( "https://www.facebook.com/yourfirm" );
				} );

				it( "is empty on a site that has set none", function(){
					expect( firm.socialsFor( site.getId() ) ).toBeEmpty();
				} );

				it( "are every one of them optional", function(){
					// Submitting the form having filled in nothing at all. No
					// field on this tab is required, so this has to be accepted
					// rather than refused with a message about a missing value.
					var blank = {};

					for ( var field in firm.getFields() ) {
						blank[ field.key ] = "";
					}

					expect( function(){
						firm.save( site.getId(), blank );
					} ).notToThrow();

					expect( firm.socialsFor( site.getId() ) ).toBeEmpty();
				} );

				it( "accepts one profile without the other six", function(){
					// They are independent: filling in LinkedIn must not oblige
					// anybody to find a TikTok account.
					expect( function(){
						firm.save( site.getId(), { linkedin : "https://www.linkedin.com/company/yourfirm" } );
					} ).notToThrow();

					var socials = firm.socialsFor( site.getId() );

					expect( socials.len() ).toBe( 1 );
					expect( socials[ 1 ].key ).toBe( "linkedin" );
				} );

				it( "lets a profile be cleared again", function(){
					firm.save( site.getId(), { facebook : "https://www.facebook.com/yourfirm" } );
					expect( firm.socialsFor( site.getId() ).len() ).toBe( 1 );

					firm.save( site.getId(), { facebook : "" } );
					expect( firm.socialsFor( site.getId() ) ).toBeEmpty();
				} );

				it( "leaves out a stored address that would not be accepted today", function(){
					// The second gate again: written straight past the service,
					// as a migration or a hand-run UPDATE would.
					settings.put( site.getId(), "firm.youtube", "javascript:alert(1)" );

					var keys = firm.socialsFor( site.getId() ).map( function( social ){
						return social.key;
					} );

					expect( keys ).notToInclude( "youtube" );
					expect( firm.firmFor( site.getId() ).youtube ).toBe( "" );
				} );

				it( "covers every network that was asked for", function(){
					var keys = firm.getFields()
						.filter( function( field ){ return ( field.group ?: "" ) == "social"; } )
						.map( function( field ){ return field.key; } );

					for ( var network in [ "facebook", "instagram", "linkedin", "x", "tiktok", "youtube", "whatsapp" ] ) {
						expect( keys ).toInclude( network );
					}
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
