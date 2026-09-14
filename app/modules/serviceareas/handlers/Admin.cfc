/**
 * Admin for services and locations used on the Service Locations page.
 *
 * Does not change public Legal Services navigation.
 */
component extends="core.models.security.SecuredHandler" {

	property name="areas" inject="ServiceAreaService@serviceareas";

	variables.permissions = {
		"index"           : "serviceareas.view",
		"newService"      : "serviceareas.manage",
		"createService"   : "serviceareas.manage",
		"editService"     : "serviceareas.manage",
		"updateService"   : "serviceareas.manage",
		"removeService"   : "serviceareas.manage",
		"newLocation"     : "serviceareas.manage",
		"createLocation"  : "serviceareas.manage",
		"editLocation"    : "serviceareas.manage",
		"updateLocation"  : "serviceareas.manage",
		"removeLocation"  : "serviceareas.manage",
		"$every"          : "serviceareas.view"
	};

	function index( event, rc, prc ){
		prc.pageTitle = "Service areas";
		prc.services  = areas.getServicesForSite( prc.currentSite.getId() );
		prc.locations = areas.getLocationsForSite( prc.currentSite.getId() );
		prc.canManage = authorization.can( prc.currentUser, "serviceareas.manage" );

		event.setView( view = "admin/index", module = "serviceareas" );
	}

	function newService( event, rc, prc ){
		prc.pageTitle = "New service";
		prc.service   = "";
		prc.locations = areas.getLocationsForSite( prc.currentSite.getId() );
		prc.selected  = [];

		event.setView( view = "admin/service-form", module = "serviceareas" );
	}

	function createService( event, rc, prc ){
		try {
			areas.createService(
				siteId      = prc.currentSite.getId(),
				name        = rc.name ?: "",
				slug        = rc.slug ?: "",
				href        = rc.href ?: "",
				sortOrder   = val( rc.sortOrder ?: 0 ),
				active      = ( rc.active ?: "" ) == "on",
				locationIds = readIds( rc.locationIds ?: "" )
			);
		} catch ( any e ) {
			return done( "/admin/serviceareas/newService", e.message, "error" );
		}

		return done( "/admin/serviceareas", "Service created." );
	}

	function editService( event, rc, prc ){
		var service = requireSiteService( rc.id ?: 0, prc );

		prc.pageTitle = "Edit service";
		prc.service   = service;
		prc.locations = areas.getLocationsForSite( prc.currentSite.getId() );
		prc.selected  = areas.getLocationIdsForService( service.getId() );

		event.setView( view = "admin/service-form", module = "serviceareas" );
	}

	function updateService( event, rc, prc ){
		var service = requireSiteService( rc.id ?: 0, prc );

		try {
			areas.updateService(
				serviceId   = service.getId(),
				name        = rc.name ?: "",
				slug        = rc.slug ?: "",
				href        = rc.href ?: "",
				sortOrder   = val( rc.sortOrder ?: 0 ),
				active      = ( rc.active ?: "" ) == "on",
				locationIds = readIds( rc.locationIds ?: "" )
			);
		} catch ( any e ) {
			return done( "/admin/serviceareas/editService/#service.getId()#", e.message, "error" );
		}

		return done( "/admin/serviceareas", "Service saved." );
	}

	function removeService( event, rc, prc ){
		var service = requireSiteService( rc.id ?: 0, prc );

		areas.deleteService( service.getId() );

		return done( "/admin/serviceareas", "Service deleted." );
	}

	function newLocation( event, rc, prc ){
		prc.pageTitle = "New location";
		prc.location  = "";

		event.setView( view = "admin/location-form", module = "serviceareas" );
	}

	function createLocation( event, rc, prc ){
		try {
			areas.createLocation(
				siteId    = prc.currentSite.getId(),
				name      = rc.name ?: "",
				slug      = rc.slug ?: "",
				region    = rc.region ?: "",
				href      = rc.href ?: "",
				sortOrder = val( rc.sortOrder ?: 0 ),
				active    = ( rc.active ?: "" ) == "on"
			);
		} catch ( any e ) {
			return done( "/admin/serviceareas/newLocation", e.message, "error" );
		}

		return done( "/admin/serviceareas", "Location created." );
	}

	function editLocation( event, rc, prc ){
		var location = requireSiteLocation( rc.id ?: 0, prc );

		prc.pageTitle = "Edit location";
		prc.location  = location;

		event.setView( view = "admin/location-form", module = "serviceareas" );
	}

	function updateLocation( event, rc, prc ){
		var location = requireSiteLocation( rc.id ?: 0, prc );

		try {
			areas.updateLocation(
				locationId = location.getId(),
				name       = rc.name ?: "",
				slug       = rc.slug ?: "",
				region     = rc.region ?: "",
				href       = rc.href ?: "",
				sortOrder  = val( rc.sortOrder ?: 0 ),
				active     = ( rc.active ?: "" ) == "on"
			);
		} catch ( any e ) {
			return done( "/admin/serviceareas/editLocation/#location.getId()#", e.message, "error" );
		}

		return done( "/admin/serviceareas", "Location saved." );
	}

	function removeLocation( event, rc, prc ){
		var location = requireSiteLocation( rc.id ?: 0, prc );

		areas.deleteLocation( location.getId() );

		return done( "/admin/serviceareas", "Location deleted." );
	}

	private function requireSiteService( required numeric serviceId, required struct prc ){
		var service = areas.getServiceById( arguments.serviceId );

		if ( isNull( service ) || service.getSiteId() != arguments.prc.currentSite.getId() ) {
			throw( type = "Admin.NotFoundHere", message = "No service [#arguments.serviceId#] on this site." );
		}

		return service;
	}

	private function requireSiteLocation( required numeric locationId, required struct prc ){
		var location = areas.getLocationById( arguments.locationId );

		if ( isNull( location ) || location.getSiteId() != arguments.prc.currentSite.getId() ) {
			throw( type = "Admin.NotFoundHere", message = "No location [#arguments.locationId#] on this site." );
		}

		return location;
	}

	private array function readIds( required any value ){
		if ( isArray( arguments.value ) ) {
			return arguments.value;
		}
		return listToArray( arguments.value );
	}

}
