/**
 * A suburb or town a service may cover.
 */
component accessors="true" {

	property name="id"        type="numeric";
	property name="siteId"    type="numeric";
	property name="name"      type="string";
	property name="slug"      type="string";
	property name="region"    type="string";
	property name="href"      type="string";
	property name="sortOrder" type="numeric";
	property name="active"    type="boolean";
	property name="createdAt";
	property name="updatedAt";

	function init(){
		variables.sortOrder = 0;
		variables.active    = true;
		variables.region    = "";
		variables.href      = "";
		return this;
	}

	struct function getMemento(){
		return {
			"id"        : variables.id,
			"siteId"    : variables.siteId,
			"name"      : variables.name,
			"slug"      : variables.slug,
			"region"    : variables.region ?: "",
			"href"      : variables.href ?: "",
			"sortOrder" : variables.sortOrder ?: 0,
			"active"    : variables.active ? true : false
		};
	}

}
