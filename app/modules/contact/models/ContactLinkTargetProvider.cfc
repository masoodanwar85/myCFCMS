/**
 * Lets a menu item point at the public contact form.
 *
 * Only the site's default (first active) form is offered: `/contact` is the
 * one URL the resolver serves. Storing `contact.form` and that form's id,
 * rather than the address, means a rename updates the menu and a deactivated
 * or deleted form drops out of it instead of linking to a 404.
 */
component singleton accessors="true" {

	property name="contactService" inject="ContactService@contact";
	property name="settings"       inject="coldbox:moduleSettings:contact";

	this.FORM = "contact.form";

	array function getLinkTargets( required numeric siteId ){
		var contactForm = contactService.getDefaultForm( arguments.siteId );

		if ( isNull( contactForm ) ) {
			return [];
		}

		return [
			{
				"type"  : this.FORM,
				"id"    : contactForm.getId(),
				"label" : contactForm.getName(),
				"path"  : basePath(),
				"group" : "Contact"
			}
		];
	}

	function resolveLinkTarget( required numeric siteId, required string type, required numeric id ){
		if ( arguments.type != this.FORM ) {
			return;
		}

		var contactForm = contactService.getFormById( arguments.id );

		if ( isNull( contactForm ) || contactForm.getSiteId() != arguments.siteId || !contactForm.getIsActive() ) {
			return;
		}

		return {
			"label" : contactForm.getName(),
			"path"  : basePath()
		};
	}

	private string function basePath(){
		return reReplace( lCase( trim( settings.basePath ?: "contact" ) ), "^/+|/+$", "", "all" );
	}

}
