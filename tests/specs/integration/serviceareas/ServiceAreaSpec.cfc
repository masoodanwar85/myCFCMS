/**
 * Service Areas: services and towns for the Service Locations page.
 *
 * Guards the two properties that matter: a site cannot see another's rows,
 * and a service with no attached locations is omitted from the public panels.
 *
 * Requires migrations to have run: `box migrate up`.
 */
component extends="coldbox.system.testing.BaseTestCase" appMapping="/app" {

	variables.PREFIX = "zzt-sa-";

	function beforeAll(){
		super.beforeAll();
		variables.sites = getInstance( "SiteService@core" );
		variables.areas = getInstance( "ServiceAreaService@serviceareas" );
		cleanup();
		seed();
	}

	function afterAll(){
		cleanup();
		super.afterAll();
	}

	function run(){
		describe( "Service areas", function(){

			beforeEach( function(){
				setup();
			} );

			it( "round-trips a service with locations", function(){
				var katoomba = areas.createLocation( siteId = siteOne.getId(), name = "Katoomba" );
				var service  = areas.createService(
					siteId      = siteOne.getId(),
					name        = "Wills",
					locationIds = [ katoomba.getId() ]
				);

				var loaded = areas.getServiceById( service.getId() );
				expect( loaded.getName() ).toBe( "Wills" );
				expect( loaded.getSlug() ).toBe( "wills" );

				var panels = areas.getPanelsForSite( siteOne.getId() );
				expect( panels.len() ).toBe( 1 );
				expect( panels[ 1 ].title ).toBe( "Wills" );
				expect( panels[ 1 ].places.len() ).toBe( 1 );
				expect( panels[ 1 ].places[ 1 ].label ).toBe( "Katoomba" );

				areas.deleteService( service.getId() );
				areas.deleteLocation( katoomba.getId() );
			} );

			it( "omits a service that has no locations", function(){
				var service = areas.createService( siteId = siteOne.getId(), name = "Orphan Service" );

				var titles = areas.getPanelsForSite( siteOne.getId() ).map( ( p ) => p.title );
				expect( titles ).notToInclude( "Orphan Service" );

				areas.deleteService( service.getId() );
			} );

			it( "omits an inactive service even when it has locations", function(){
				var place = areas.createLocation( siteId = siteOne.getId(), name = "Leura" );
				var service = areas.createService(
					siteId      = siteOne.getId(),
					name        = "Hidden Service",
					active      = false,
					locationIds = [ place.getId() ]
				);

				var titles = areas.getPanelsForSite( siteOne.getId() ).map( ( p ) => p.title );
				expect( titles ).notToInclude( "Hidden Service" );

				areas.deleteService( service.getId() );
				areas.deleteLocation( place.getId() );
			} );

			it( "does not leak another site's services", function(){
				var place = areas.createLocation( siteId = siteTwo.getId(), name = "Parkes" );
				areas.createService(
					siteId      = siteTwo.getId(),
					name        = "Probate",
					locationIds = [ place.getId() ]
				);

				var titles = areas.getPanelsForSite( siteOne.getId() ).map( ( p ) => p.title );
				expect( titles ).notToInclude( "Probate" );
			} );

			it( "refuses a duplicate slug on one site", function(){
				areas.createService( siteId = siteOne.getId(), name = "Estate Planning" );

				expect( function(){
					areas.createService( siteId = siteOne.getId(), name = "Estate Planning" );
				} ).toThrow( type = "ServiceAreas.ServiceSlugExists" );
			} );

			it( "allows the same slug on a different site", function(){
				var service = areas.createService( siteId = siteTwo.getId(), name = "Estate Planning" );
				expect( service.getSlug() ).toBe( "estate-planning" );
			} );

			it( "does not register public navigation", function(){
				var ids = getInstance( "SiteNavigationRegistry@core" ).getRegistered();
				expect( arrayToList( ids ) ).notToInclude( "serviceareas" );
			} );

			it( "registers its own admin navigation", function(){
				var hrefs = getInstance( "AdminNavigationRegistry@core" )
					.getSections()
					.map( ( s ) => s.href );

				expect( hrefs ).toInclude( "/admin/serviceareas" );
			} );

		} );
	}

	private function seed(){
		variables.siteOne = sites.createSite( name = "Areas One", slug = PREFIX & "one" );
		sites.addDomain( siteOne.getId(), "#PREFIX#one.test" );

		variables.siteTwo = sites.createSite( name = "Areas Two", slug = PREFIX & "two" );
		sites.addDomain( siteTwo.getId(), "#PREFIX#two.test" );
	}

	private function cleanup(){
		queryExecute( "DELETE FROM sites WHERE slug LIKE :p", { p : PREFIX & "%" } );
	}

}
