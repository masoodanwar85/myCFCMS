/**
 * Lets a menu item point at the public will questionnaire.
 *
 * The form is a singleton like the blog archive: there is no row to store, so
 * the type is `will.form` and the id is 0. Storing that pair rather than `/will`
 * means a change to `basePath` moves every menu that links here.
 */
component singleton accessors="true" {

	property name="settings" inject="coldbox:moduleSettings:will";

	this.FORM = "will.form";

	array function getLinkTargets( required numeric siteId ){
		return [
			{
				"type"  : this.FORM,
				"id"    : 0,
				"label" : formTitle(),
				"path"  : basePath(),
				"group" : "Will"
			}
		];
	}

	function resolveLinkTarget( required numeric siteId, required string type, required numeric id ){
		if ( arguments.type != this.FORM ) {
			return;
		}

		return {
			"label" : formTitle(),
			"path"  : basePath()
		};
	}

	private string function formTitle(){
		return settings.formTitle ?: "Create your will";
	}

	private string function basePath(){
		return reReplace( lCase( trim( settings.basePath ?: "will" ) ), "^/+|/+$", "", "all" );
	}

}
