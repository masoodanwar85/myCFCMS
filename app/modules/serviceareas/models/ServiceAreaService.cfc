/**
 * Services, locations, and which towns a service covers.
 *
 * The Service Locations page is the only public reader. Legal Services
 * navigation does not use this module.
 */
component singleton accessors="true" {

	property name="serviceRepository"  inject="ServiceRepository@serviceareas";
	property name="locationRepository" inject="LocationRepository@serviceareas";
	property name="siteRepository"     inject="SiteRepository@core";
	property name="slugifier"          inject="Slugifier@core";
	property name="wirebox"            inject="wirebox";

	/**
	 * Tabs and town grids for the public template.
	 *
	 * A service with no attached active locations is omitted.
	 */
	array function getPanelsForSite( required numeric siteId ){
		return serviceRepository.findPanelsForSite( arguments.siteId );
	}

	array function getServicesForSite( required numeric siteId ){
		return serviceRepository.findWithLocationCounts( arguments.siteId );
	}

	array function getLocationsForSite( required numeric siteId ){
		return locationRepository.findBySiteId( arguments.siteId );
	}

	function getServiceById( required numeric serviceId ){
		return serviceRepository.findById( arguments.serviceId );
	}

	function getLocationById( required numeric locationId ){
		return locationRepository.findById( arguments.locationId );
	}

	array function getLocationIdsForService( required numeric serviceId ){
		return serviceRepository.findLocationIds( arguments.serviceId );
	}

	/**
	 * @throws ServiceAreas.SiteNotFound
	 * @throws ServiceAreas.InvalidService
	 * @throws ServiceAreas.ServiceSlugExists
	 */
	serviceareas.models.Service function createService(
		required numeric siteId,
		required string name,
		string slug      = "",
		string href      = "",
		numeric sortOrder = 0,
		boolean active    = true,
		array locationIds = []
	){
		requireSite( arguments.siteId );

		var serviceName = trim( arguments.name );
		if ( !len( serviceName ) ) {
			throw( type = "ServiceAreas.InvalidService", message = "A service requires a name." );
		}

		var serviceSlug = len( trim( arguments.slug ) ) ? slugify( arguments.slug ) : slugify( serviceName );
		if ( !len( serviceSlug ) ) {
			throw( type = "ServiceAreas.InvalidService", message = "Could not derive a usable slug from [#serviceName#]." );
		}

		var service = wirebox
			.getInstance( "Service@serviceareas" )
			.setSiteId( arguments.siteId )
			.setName( serviceName )
			.setSlug( serviceSlug )
			.setHref( normaliseHref( arguments.href ) )
			.setSortOrder( val( arguments.sortOrder ) )
			.setActive( arguments.active ? true : false );

		serviceRepository.create( service );
		var ids = numericIds( arguments.locationIds );
		serviceRepository.replaceLocations(
			siteId     = arguments.siteId,
			serviceId  = service.getId(),
			locationIds = ids,
			hrefByLocationId = hrefsFor( arguments.siteId, ids )
		);

		return service;
	}

	/**
	 * @throws ServiceAreas.ServiceNotFound
	 * @throws ServiceAreas.InvalidService
	 * @throws ServiceAreas.ServiceSlugExists
	 */
	serviceareas.models.Service function updateService(
		required numeric serviceId,
		required string name,
		string slug       = "",
		string href       = "",
		numeric sortOrder = 0,
		boolean active    = true,
		array locationIds = []
	){
		var service = requireService( arguments.serviceId );
		var serviceName = trim( arguments.name );

		if ( !len( serviceName ) ) {
			throw( type = "ServiceAreas.InvalidService", message = "A service requires a name." );
		}

		var serviceSlug = len( trim( arguments.slug ) ) ? slugify( arguments.slug ) : slugify( serviceName );
		if ( !len( serviceSlug ) ) {
			throw( type = "ServiceAreas.InvalidService", message = "Could not derive a usable slug from [#serviceName#]." );
		}

		service
			.setName( serviceName )
			.setSlug( serviceSlug )
			.setHref( normaliseHref( arguments.href ) )
			.setSortOrder( val( arguments.sortOrder ) )
			.setActive( arguments.active ? true : false );

		serviceRepository.update( service );
		var ids = numericIds( arguments.locationIds );
		serviceRepository.replaceLocations(
			siteId     = service.getSiteId(),
			serviceId  = service.getId(),
			locationIds = ids,
			hrefByLocationId = hrefsFor( service.getSiteId(), ids )
		);

		return service;
	}

	function deleteService( required numeric serviceId ){
		requireService( arguments.serviceId );
		serviceRepository.delete( arguments.serviceId );
		return this;
	}

	/**
	 * @throws ServiceAreas.SiteNotFound
	 * @throws ServiceAreas.InvalidLocation
	 * @throws ServiceAreas.LocationSlugExists
	 */
	serviceareas.models.Location function createLocation(
		required numeric siteId,
		required string name,
		string slug       = "",
		string region     = "",
		string href       = "",
		numeric sortOrder = 0,
		boolean active    = true
	){
		requireSite( arguments.siteId );

		var locationName = trim( arguments.name );
		if ( !len( locationName ) ) {
			throw( type = "ServiceAreas.InvalidLocation", message = "A location requires a name." );
		}

		var locationSlug = len( trim( arguments.slug ) ) ? slugify( arguments.slug ) : slugify( locationName );
		if ( !len( locationSlug ) ) {
			throw( type = "ServiceAreas.InvalidLocation", message = "Could not derive a usable slug from [#locationName#]." );
		}

		var location = wirebox
			.getInstance( "Location@serviceareas" )
			.setSiteId( arguments.siteId )
			.setName( locationName )
			.setSlug( locationSlug )
			.setRegion( trim( arguments.region ) )
			.setHref( normaliseHref( arguments.href ) )
			.setSortOrder( val( arguments.sortOrder ) )
			.setActive( arguments.active ? true : false );

		return locationRepository.create( location );
	}

	/**
	 * @throws ServiceAreas.LocationNotFound
	 * @throws ServiceAreas.InvalidLocation
	 * @throws ServiceAreas.LocationSlugExists
	 */
	serviceareas.models.Location function updateLocation(
		required numeric locationId,
		required string name,
		string slug       = "",
		string region     = "",
		string href       = "",
		numeric sortOrder = 0,
		boolean active    = true
	){
		var location = requireLocation( arguments.locationId );
		var locationName = trim( arguments.name );

		if ( !len( locationName ) ) {
			throw( type = "ServiceAreas.InvalidLocation", message = "A location requires a name." );
		}

		var locationSlug = len( trim( arguments.slug ) ) ? slugify( arguments.slug ) : slugify( locationName );
		if ( !len( locationSlug ) ) {
			throw( type = "ServiceAreas.InvalidLocation", message = "Could not derive a usable slug from [#locationName#]." );
		}

		location
			.setName( locationName )
			.setSlug( locationSlug )
			.setRegion( trim( arguments.region ) )
			.setHref( normaliseHref( arguments.href ) )
			.setSortOrder( val( arguments.sortOrder ) )
			.setActive( arguments.active ? true : false );

		return locationRepository.update( location );
	}

	function deleteLocation( required numeric locationId ){
		requireLocation( arguments.locationId );
		locationRepository.delete( arguments.locationId );
		return this;
	}

	string function slugify( required string value ){
		return slugifier.slugify( arguments.value );
	}

	private array function numericIds( required array ids ){
		var out = [];
		for ( var id in arguments.ids ) {
			var n = val( id );
			if ( n && !arrayFind( out, n ) ) {
				arrayAppend( out, n );
			}
		}
		return out;
	}

	private function hrefsFor( required numeric siteId, required array locationIds ){
		var hrefs = {};
		var wanted = numericIds( arguments.locationIds );
		var all    = locationRepository.findBySiteId( arguments.siteId );

		for ( var location in all ) {
			if ( arrayFind( wanted, location.getId() ) ) {
				hrefs[ location.getId() ] = location.getHref() ?: "";
			}
		}

		return hrefs;
	}

	private string function normaliseHref( required string href ){
		var value = trim( arguments.href );
		if ( !len( value ) ) {
			return "";
		}
		if ( reFindNoCase( "^https?://", value ) || left( value, 1 ) == "/" ) {
			return left( value, 500 );
		}
		return "/" & left( reReplace( value, "^/+", "" ), 499 );
	}

	private function requireSite( required numeric siteId ){
		if ( isNull( siteRepository.findById( arguments.siteId ) ) ) {
			throw( type = "ServiceAreas.SiteNotFound", message = "No site with id [#arguments.siteId#]." );
		}
	}

	private function requireService( required numeric serviceId ){
		var service = serviceRepository.findById( arguments.serviceId );

		if ( isNull( service ) ) {
			throw( type = "ServiceAreas.ServiceNotFound", message = "No service with id [#arguments.serviceId#]." );
		}

		return service;
	}

	private function requireLocation( required numeric locationId ){
		var location = locationRepository.findById( arguments.locationId );

		if ( isNull( location ) ) {
			throw( type = "ServiceAreas.LocationNotFound", message = "No location with id [#arguments.locationId#]." );
		}

		return location;
	}

}
