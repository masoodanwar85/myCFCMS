/**
 * Contributes a "Create your will" entry to a site's automatic public navigation.
 *
 * Sites with a curated menu do not use this; those pick the form through
 * WillLinkTargetProvider in the menu editor.
 */
component singleton accessors="true" {

	property name="settings" inject="coldbox:moduleSettings:will";

	array function getNavigationItems( required numeric siteId ){
		var base = reReplace( lCase( trim( settings.basePath ?: "will" ) ), "^/+|/+$", "", "all" );

		return [
			{
				"label" : settings.formTitle ?: "Create your will",
				"href"  : "/" & base,
				"order" : val( settings.navigationOrder ?: 850 )
			}
		];
	}

}
