/**
 * The Group 1 requirements end-to-end against a real MySQL schema.
 *
 * These specs exist because the unit specs deliberately stub the database, and
 * the most important guarantees in this design — a domain belonging to exactly
 * one site, one primary domain per site, one value per (site, key) — are
 * enforced by indexes, not by CFML. Stubbing those away would test nothing.
 *
 * Requires migrations to have run against the configured datasource:
 *
 *     box migrate up
 *
 * Every row created here uses the `zzt-` prefix and is removed afterwards.
 */
component extends="coldbox.system.testing.BaseTestCase" appMapping="/app" {

	variables.PREFIX = "zzt-";

	function beforeAll(){
		super.beforeAll();
		variables.service      = getInstance( "SiteService@core" );
		variables.siteRepo     = getInstance( "SiteRepository@core" );
		variables.domainRepo   = getInstance( "SiteDomainRepository@core" );
		variables.settingsRepo = getInstance( "SiteSettingsRepository@core" );
		cleanup();
	}

	function afterAll(){
		cleanup();
		super.afterAll();
	}

	function run(){
		describe( "Tenancy persistence", function(){

			afterEach( function(){
				cleanup();
			} );

			describe( "creating a site", function(){

				it( "round-trips a site through the database", function(){
					var created = newSite( "Client One" );

					expect( created.getId() ).toBeGT( 0 );

					var loaded = siteRepo.findById( created.getId() );

					expect( isNull( loaded ) ).toBeFalse();
					expect( loaded.getName() ).toBe( "Client One" );
					expect( loaded.getSlug() ).toBe( created.getSlug() );
					expect( loaded.getStatus() ).toBe( "active" );
					expect( loaded.getTimezone() ).toBe( "UTC" );
					expect( loaded.isActive() ).toBeTrue();
					expect( isNull( loaded.getCreatedAt() ) ).toBeFalse();
				} );

				it( "is findable by slug", function(){
					var created = newSite( "Client Two" );
					var loaded  = siteRepo.findBySlug( created.getSlug() );

					expect( isNull( loaded ) ).toBeFalse();
					expect( loaded.getId() ).toBe( created.getId() );
				} );

				it( "returns null for an id that does not exist", function(){
					expect( isNull( siteRepo.findById( 987654321 ) ) ).toBeTrue();
				} );

				it( "refuses a duplicate slug at the database level", function(){
					var created = newSite( "Client Three" );

					// Bypasses the service's pre-check, so this is the unique index talking.
					expect( function(){
						siteRepo.create(
							getInstance( "Site@core" )
								.setName( "Impostor" )
								.setSlug( created.getSlug() )
						);
					} ).toThrow( type = "Tenancy.SlugAlreadyTaken" );
				} );

			} );

			describe( "assigning domains", function(){

				it( "attaches multiple domains to one site", function(){
					var site = newSite( "Client Four" );

					service.addDomain( site.getId(), "#PREFIX#four.com" );
					service.addDomain( site.getId(), "www.#PREFIX#four.com" );

					var domains = service.getDomains( site.getId() );

					expect( domains.len() ).toBe( 2 );
					expect( domains.map( ( d ) => d.getDomain() ) ).toInclude( "#PREFIX#four.com" );
					expect( domains.map( ( d ) => d.getDomain() ) ).toInclude( "www.#PREFIX#four.com" );
				} );

				it( "marks the first domain primary and the rest secondary", function(){
					var site = newSite( "Client Five" );

					service.addDomain( site.getId(), "#PREFIX#five.com" );
					service.addDomain( site.getId(), "www.#PREFIX#five.com" );

					var primary = domainRepo.findPrimaryForSite( site.getId() );

					expect( isNull( primary ) ).toBeFalse();
					expect( primary.getDomain() ).toBe( "#PREFIX#five.com" );
				} );

				it( "keeps only one primary domain per site when promoting another", function(){
					var site = newSite( "Client Six" );

					service.addDomain( site.getId(), "#PREFIX#six.com" );
					service.addDomain( site.getId(), "www.#PREFIX#six.com" );

					service.makeDomainPrimary( site.getId(), "www.#PREFIX#six.com" );

					var domains = service.getDomains( site.getId() );
					var primaries = domains.filter( ( d ) => d.getIsPrimary() );

					expect( primaries.len() ).toBe( 1 );
					expect( primaries[ 1 ].getDomain() ).toBe( "www.#PREFIX#six.com" );
				} );

				it( "removes a site's domains when the site is deleted", function(){
					var site = newSite( "Client Seven" );
					service.addDomain( site.getId(), "#PREFIX#seven.com" );

					queryExecute( "DELETE FROM sites WHERE id = :id", { id : site.getId() } );

					expect( isNull( domainRepo.findByDomain( "#PREFIX#seven.com" ) ) ).toBeTrue();
				} );

			} );

			describe( "preventing duplicate domain ownership", function(){

				it( "refuses to give one domain to a second site", function(){
					var siteA = newSite( "Client Eight A" );
					var siteB = newSite( "Client Eight B" );

					service.addDomain( siteA.getId(), "#PREFIX#eight.com" );

					expect( function(){
						service.addDomain( siteB.getId(), "#PREFIX#eight.com" );
					} ).toThrow( type = "Tenancy.DomainAlreadyAssigned" );

					// Ownership is unchanged.
					expect( domainRepo.findByDomain( "#PREFIX#eight.com" ).getSiteId() ).toBe( siteA.getId() );
				} );

				it( "enforces exclusivity in the database, not only in the service", function(){
					var siteA = newSite( "Client Nine A" );
					var siteB = newSite( "Client Nine B" );

					service.addDomain( siteA.getId(), "#PREFIX#nine.com" );

					// Straight at the repository, skipping the service's pre-check.
					expect( function(){
						domainRepo.create(
							getInstance( "SiteDomain@core" )
								.setSiteId( siteB.getId() )
								.setDomain( "#PREFIX#nine.com" )
						);
					} ).toThrow( type = "Tenancy.DomainAlreadyAssigned" );
				} );

				it( "refuses the same domain twice on the same site", function(){
					var site = newSite( "Client Ten" );

					service.addDomain( site.getId(), "#PREFIX#ten.com" );

					expect( function(){
						service.addDomain( site.getId(), "#PREFIX#ten.com" );
					} ).toThrow( type = "Tenancy.DomainAlreadyAssigned" );
				} );

			} );

			describe( "saving site settings", function(){

				it( "stores and reads back a value", function(){
					var site = newSite( "Client Eleven" );

					service.setSetting( site.getId(), "seo.defaultTitle", "Client Eleven" );

					expect( service.getSetting( site.getId(), "seo.defaultTitle" ) ).toBe( "Client Eleven" );
				} );

				it( "overwrites rather than duplicating an existing key", function(){
					var site = newSite( "Client Twelve" );

					service.setSetting( site.getId(), "seo.defaultTitle", "First" );
					service.setSetting( site.getId(), "seo.defaultTitle", "Second" );

					expect( service.getSetting( site.getId(), "seo.defaultTitle" ) ).toBe( "Second" );
					expect( service.getSettings( site.getId() ).count() ).toBe( 1 );
				} );

				it( "keeps each site's settings separate", function(){
					var siteA = newSite( "Client Thirteen A" );
					var siteB = newSite( "Client Thirteen B" );

					service.setSetting( siteA.getId(), "theme", "alpha" );
					service.setSetting( siteB.getId(), "theme", "beta" );

					expect( service.getSetting( siteA.getId(), "theme" ) ).toBe( "alpha" );
					expect( service.getSetting( siteB.getId(), "theme" ) ).toBe( "beta" );
				} );

				it( "returns the default for a key that was never set", function(){
					var site = newSite( "Client Fourteen" );

					expect( service.getSetting( site.getId(), "nope", "fallback" ) ).toBe( "fallback" );
				} );

				it( "returns every setting for a site in one struct", function(){
					var site = newSite( "Client Fifteen" );

					service.setSetting( site.getId(), "a", "1" );
					service.setSetting( site.getId(), "b", "2" );

					var all = service.getSettings( site.getId() );

					expect( all ).toHaveKey( "a" );
					expect( all ).toHaveKey( "b" );
					expect( all.a ).toBe( "1" );
				} );

				it( "removes a site's settings when the site is deleted", function(){
					var site = newSite( "Client Sixteen" );
					service.setSetting( site.getId(), "theme", "alpha" );

					queryExecute( "DELETE FROM sites WHERE id = :id", { id : site.getId() } );

					expect( settingsRepo.getAllForSite( site.getId() ).isEmpty() ).toBeTrue();
				} );

			} );

			describe( "resolving a site from a domain", function(){

				it( "finds the active site behind an active domain", function(){
					var site = newSite( "Client Seventeen" );
					service.addDomain( site.getId(), "#PREFIX#seventeen.com" );

					var resolved = siteRepo.findActiveByDomain( "#PREFIX#seventeen.com" );

					expect( isNull( resolved ) ).toBeFalse();
					expect( resolved.getId() ).toBe( site.getId() );
				} );

				it( "returns null for an unknown domain", function(){
					expect( isNull( siteRepo.findActiveByDomain( "#PREFIX#nobody.com" ) ) ).toBeTrue();
				} );

				it( "will not resolve a deactivated domain", function(){
					var site   = newSite( "Client Eighteen" );
					var domain = service.addDomain( site.getId(), "#PREFIX#eighteen.com" );

					domainRepo.setActive( domain.getId(), false );

					expect( isNull( siteRepo.findActiveByDomain( "#PREFIX#eighteen.com" ) ) ).toBeTrue();
				} );

				it( "will not resolve a domain belonging to an inactive site", function(){
					var site = newSite( "Client Nineteen" );
					service.addDomain( site.getId(), "#PREFIX#nineteen.com" );

					siteRepo.update( site.setStatus( "inactive" ) );

					expect( isNull( siteRepo.findActiveByDomain( "#PREFIX#nineteen.com" ) ) ).toBeTrue();
				} );

			} );

			describe( "TenantResolver against the real schema", function(){

				it( "resolves a live domain to its site", function(){
					var site = newSite( "Client Twenty" );
					service.addDomain( site.getId(), "#PREFIX#twenty.com" );

					var resolver = getInstance( "TenantResolver@core" );
					var resolved = resolver.resolveByDomain( "HTTPS://#PREFIX#twenty.com:8080/some/path" );

					expect( isNull( resolved ) ).toBeFalse();
					expect( resolved.getId() ).toBe( site.getId() );
				} );

				it( "returns null for an unknown domain", function(){
					var resolver = getInstance( "TenantResolver@core" );

					expect( isNull( resolver.resolveByDomain( "#PREFIX#unknown.example" ) ) ).toBeTrue();
				} );

			} );

		} );
	}

	/**
	 * Create a site whose slug carries the test prefix, so cleanup can find it.
	 */
	private function newSite( required string name ){
		return service.createSite(
			name = arguments.name,
			slug = PREFIX & service.slugify( arguments.name ) & "-" & createUUID().left( 8 )
		);
	}

	/**
	 * Remove every row this spec could have created.
	 * Domains and settings go with the site through ON DELETE CASCADE.
	 */
	private function cleanup(){
		queryExecute( "DELETE FROM sites WHERE slug LIKE :prefix", { prefix : PREFIX & "%" } );
	}

}
