/**
 * Requirements 1-4 at the service layer: creating a site, assigning domains,
 * refusing a domain that already belongs to someone, and saving settings.
 *
 * Repositories are stubbed, so what is under test here is the service's own
 * validation and orchestration. The database constraints that back the same
 * rules are verified in the integration specs.
 */
component extends="coldbox.system.testing.BaseTestCase" appMapping="/app" {

	function beforeAll(){
		super.beforeAll();
	}

	function afterAll(){
		super.afterAll();
	}

	function run(){
		describe( "SiteService", function(){

			beforeEach( function(){
				variables.siteRepo     = createStub();
				variables.domainRepo   = createStub();
				variables.settingsRepo = createStub();

				// Default world: nothing exists yet.
				siteRepo.$( "existsBySlug", false );
				siteRepo.$( "create" );
				domainRepo.$( "existsByDomain", false );
				domainRepo.$( "findBySiteId", [] );
				domainRepo.$( "findPrimaryForSite" );

				variables.service = createMock( "core.models.tenancy.SiteService" )
					.setSiteRepository( siteRepo )
					.setSiteDomainRepository( domainRepo )
					.setSiteSettingsRepository( settingsRepo )
					.setDomainNormalizer( getInstance( "DomainNormalizer@core" ) )
					.setWirebox( getWireBox() );
			} );

			describe( "creating a site", function(){

				it( "persists a site with the supplied values", function(){
					siteRepo.$( "create", makeSite( 1, "Client One", "client-one" ) );

					var site = service.createSite(
						name     = "Client One",
						slug     = "client-one",
						timezone = "Europe/London",
						locale   = "en_GB"
					);

					expect( site.getId() ).toBe( 1 );

					var persisted = siteRepo.$callLog().create[ 1 ][ 1 ];
					expect( persisted.getName() ).toBe( "Client One" );
					expect( persisted.getSlug() ).toBe( "client-one" );
					expect( persisted.getTimezone() ).toBe( "Europe/London" );
					expect( persisted.getLocale() ).toBe( "en_GB" );
					expect( persisted.getStatus() ).toBe( "active" );
				} );

				it( "derives a slug from the name when none is given", function(){
					siteRepo.$( "create", makeSite( 1, "Client One Ltd.", "client-one-ltd" ) );

					service.createSite( name = "Client One Ltd." );

					expect( siteRepo.$callLog().create[ 1 ][ 1 ].getSlug() ).toBe( "client-one-ltd" );
				} );

				it( "defaults to an active site in UTC", function(){
					siteRepo.$( "create", makeSite( 1, "Client", "client" ) );

					service.createSite( name = "Client" );

					var persisted = siteRepo.$callLog().create[ 1 ][ 1 ];
					expect( persisted.getStatus() ).toBe( "active" );
					expect( persisted.getTimezone() ).toBe( "UTC" );
				} );

				it( "rejects a site with no name", function(){
					expect( function(){
						service.createSite( name = "   " );
					} ).toThrow( type = "Tenancy.InvalidSite" );
				} );

				it( "rejects an unknown status", function(){
					expect( function(){
						service.createSite( name = "Client", status = "archived" );
					} ).toThrow( type = "Tenancy.InvalidSite" );
				} );

				it( "rejects a name that yields no usable slug", function(){
					expect( function(){
						service.createSite( name = "!!!" );
					} ).toThrow( type = "Tenancy.InvalidSite" );
				} );

				it( "refuses to reuse a slug", function(){
					siteRepo.$( "existsBySlug", true );

					expect( function(){
						service.createSite( name = "Client One" );
					} ).toThrow( type = "Tenancy.SlugAlreadyTaken" );
				} );

			} );

			describe( "assigning domains", function(){

				beforeEach( function(){
					siteRepo.$( "findById", makeSite( 5, "Client One", "client-one" ) );
					domainRepo.$( "create" );
				} );

				it( "attaches a normalised domain to the site", function(){
					domainRepo.$( "create", makeDomain( 1, 5, "client.com", true ) );

					service.addDomain( siteId = 5, domain = "  HTTPS://Client.COM:443/  " );

					var persisted = domainRepo.$callLog().create[ 1 ][ 1 ];
					expect( persisted.getDomain() ).toBe( "client.com" );
					expect( persisted.getSiteId() ).toBe( 5 );
					expect( persisted.getIsActive() ).toBeTrue();
				} );

				it( "makes the site's first domain primary automatically", function(){
					domainRepo.$( "create", makeDomain( 1, 5, "client.com", true ) );

					service.addDomain( siteId = 5, domain = "client.com" );

					expect( domainRepo.$callLog().create[ 1 ][ 1 ].getIsPrimary() ).toBeTrue();
				} );

				it( "leaves later domains secondary", function(){
					domainRepo.$( "findBySiteId", [ makeDomain( 1, 5, "client.com", true ) ] );
					domainRepo.$( "create", makeDomain( 2, 5, "www.client.com", false ) );

					service.addDomain( siteId = 5, domain = "www.client.com" );

					expect( domainRepo.$callLog().create[ 1 ][ 1 ].getIsPrimary() ).toBeFalse();
				} );

				it( "treats www and the bare domain as two separate domains", function(){
					domainRepo.$( "findBySiteId", [ makeDomain( 1, 5, "client.com", true ) ] );
					domainRepo.$( "create", makeDomain( 2, 5, "www.client.com", false ) );

					service.addDomain( siteId = 5, domain = "www.client.com" );

					expect( domainRepo.$callLog().create[ 1 ][ 1 ].getDomain() ).toBe( "www.client.com" );
				} );

				it( "demotes the previous primary before promoting a new one", function(){
					domainRepo.$( "findBySiteId", [ makeDomain( 1, 5, "client.com", true ) ] );
					domainRepo.$( "findPrimaryForSite", makeDomain( 1, 5, "client.com", true ) );
					domainRepo.$( "setPrimaryFlag" );
					domainRepo.$( "create", makeDomain( 2, 5, "new.client.com", true ) );

					service.addDomain( siteId = 5, domain = "new.client.com", isPrimary = true );

					expect( domainRepo.$count( "setPrimaryFlag" ) ).toBe( 1 );
					expect( domainRepo.$callLog().setPrimaryFlag[ 1 ][ 2 ] ).toBeFalse();
				} );

				it( "rejects an unusable hostname", function(){
					expect( function(){
						service.addDomain( siteId = 5, domain = "not a domain" );
					} ).toThrow( type = "Tenancy.InvalidDomain" );
				} );

				it( "rejects a domain for a site that does not exist", function(){
					siteRepo.$( "findById" );

					expect( function(){
						service.addDomain( siteId = 999, domain = "client.com" );
					} ).toThrow( type = "Tenancy.SiteNotFound" );
				} );

			} );

			describe( "preventing duplicate domain ownership", function(){

				it( "refuses a domain that already belongs to a site", function(){
					siteRepo.$( "findById", makeSite( 6, "Client Two", "client-two" ) );
					domainRepo.$( "existsByDomain", true );
					domainRepo.$( "create" );

					expect( function(){
						service.addDomain( siteId = 6, domain = "client.com" );
					} ).toThrow( type = "Tenancy.DomainAlreadyAssigned" );

					// The write must never be attempted.
					expect( domainRepo.$count( "create" ) ).toBe( 0 );
				} );

				it( "detects the duplicate after normalisation, not before", function(){
					siteRepo.$( "findById", makeSite( 6, "Client Two", "client-two" ) );
					domainRepo.$( "existsByDomain", true );

					expect( function(){
						service.addDomain( siteId = 6, domain = "HTTPS://Client.com:8080/x" );
					} ).toThrow( type = "Tenancy.DomainAlreadyAssigned" );

					expect( domainRepo.$callLog().existsByDomain[ 1 ][ 1 ] ).toBe( "client.com" );
				} );

			} );

			describe( "saving site settings", function(){

				beforeEach( function(){
					siteRepo.$( "findById", makeSite( 5, "Client One", "client-one" ) );
				} );

				it( "writes a setting for the site", function(){
					settingsRepo.$( "put", makeSetting( 1, 5, "seo.title", "Client One" ) );

					var setting = service.setSetting( 5, "seo.title", "Client One" );

					expect( setting.getSettingKey() ).toBe( "seo.title" );
					expect( setting.getSettingValue() ).toBe( "Client One" );

					var call = settingsRepo.$callLog().put[ 1 ];
					expect( call[ 1 ] ).toBe( 5 );
					expect( call[ 2 ] ).toBe( "seo.title" );
					expect( call[ 3 ] ).toBe( "Client One" );
				} );

				it( "trims the key before storing it", function(){
					settingsRepo.$( "put", makeSetting( 1, 5, "seo.title", "x" ) );

					service.setSetting( 5, "  seo.title  ", "x" );

					expect( settingsRepo.$callLog().put[ 1 ][ 2 ] ).toBe( "seo.title" );
				} );

				it( "rejects an empty key", function(){
					expect( function(){
						service.setSetting( 5, "   ", "x" );
					} ).toThrow( type = "Tenancy.InvalidSetting" );
				} );

				it( "rejects settings for a site that does not exist", function(){
					siteRepo.$( "findById" );

					expect( function(){
						service.setSetting( 999, "seo.title", "x" );
					} ).toThrow( type = "Tenancy.SiteNotFound" );
				} );

				it( "returns the default when a key is not set", function(){
					settingsRepo.$( "getValue", "fallback" );

					expect( service.getSetting( 5, "missing.key", "fallback" ) ).toBe( "fallback" );
				} );

			} );

		} );
	}

	private function makeSite( required numeric id, required string name, required string slug ){
		return getInstance( "Site@core" )
			.setId( arguments.id )
			.setName( arguments.name )
			.setSlug( arguments.slug );
	}

	private function makeDomain(
		required numeric id,
		required numeric siteId,
		required string domain,
		required boolean isPrimary
	){
		return getInstance( "SiteDomain@core" )
			.setId( arguments.id )
			.setSiteId( arguments.siteId )
			.setDomain( arguments.domain )
			.setIsPrimary( arguments.isPrimary )
			.setIsActive( true );
	}

	private function makeSetting(
		required numeric id,
		required numeric siteId,
		required string key,
		required string value
	){
		return getInstance( "SiteSetting@core" )
			.setId( arguments.id )
			.setSiteId( arguments.siteId )
			.setSettingKey( arguments.key )
			.setSettingValue( arguments.value );
	}

}
