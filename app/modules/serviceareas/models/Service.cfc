/**
 * A service shown as a tab on the Service Locations page.
 *
 * Independent of the Legal Services page tree. `href` is optional and is
 * only used if a suburb has no pairing URL of its own.
 */
component accessors="true" {

	property name="id"        type="numeric";
	property name="siteId"    type="numeric";
	property name="name"      type="string";
	property name="slug"      type="string";
	property name="href"      type="string";
	property name="sortOrder" type="numeric";
	property name="active"    type="boolean";
	property name="createdAt";
	property name="updatedAt";
	property name="locationCount" type="numeric";

	function init(){
		variables.sortOrder     = 0;
		variables.active        = true;
		variables.href          = "";
		variables.locationCount = 0;
		return this;
	}

	struct function getMemento(){
		return {
			"id"            : variables.id,
			"siteId"        : variables.siteId,
			"name"          : variables.name,
			"slug"          : variables.slug,
			"href"          : variables.href ?: "",
			"sortOrder"     : variables.sortOrder ?: 0,
			"active"        : variables.active ? true : false,
			"locationCount" : variables.locationCount ?: 0
		};
	}

}
