/**
 * A blog category, owned by one site.
 */
component accessors="true" {

	property name="id"          type="numeric";
	property name="siteId"      type="numeric";
	property name="name"        type="string";
	property name="slug"        type="string";
	property name="description" type="string";
	property name="createdAt";
	property name="updatedAt";

	// Only populated by listings that ask for counts.
	property name="postCount" type="numeric";

	function init(){
		variables.postCount = 0;
		return this;
	}

	struct function getMemento(){
		return {
			"id"          : variables.id,
			"siteId"      : variables.siteId,
			"name"        : variables.name,
			"slug"        : variables.slug,
			"description" : variables.description ?: "",
			"postCount"   : variables.postCount ?: 0
		};
	}

}
