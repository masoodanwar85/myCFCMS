/**
 * Contributes a "Contact" entry to a site's public navigation, when the site
 * has an active form to send people to.
 */
component singleton accessors="true" {

	property name="contactService" inject="ContactService@contact";
	property name="settings"       inject="coldbox:moduleSettings:contact";

	array function getNavigationItems( required numeric siteId ){
		var contactForm = contactService.getDefaultForm( arguments.siteId );

		if ( isNull( contactForm ) ) {
			return [];
		}

		var base = reReplace( lCase( trim( settings.basePath ?: "contact" ) ), "^/+|/+$", "", "all" );

		return [
			{
				"label" : contactForm.getName(),
				"href"  : "/" & base,
				// Last by convention: contact is where a menu usually ends.
				"order" : val( settings.navigationOrder ?: 900 )
			}
		];
	}

}
