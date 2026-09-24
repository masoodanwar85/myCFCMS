/**
 * One frequently asked question, scoped to a site.
 */
component accessors="true" {

	property name="id"          type="numeric";
	property name="siteId"      type="numeric";
	property name="question"    type="string";
	property name="answer"      type="string";
	property name="sortOrder"   type="numeric";
	property name="isPublished" type="boolean";
	property name="createdAt";
	property name="updatedAt";

	function init(){
		variables.answer      = "";
		variables.sortOrder   = 0;
		variables.isPublished = false;
		return this;
	}

	struct function getMemento(){
		return {
			"id"          : variables.id,
			"siteId"      : variables.siteId,
			"question"    : variables.question,
			"answer"      : variables.answer ?: "",
			"sortOrder"   : variables.sortOrder ?: 0,
			"isPublished" : variables.isPublished ? true : false,
			"createdAt"   : isNull( variables.createdAt ) ? "" : dateTimeFormat( variables.createdAt, "iso" ),
			"updatedAt"   : isNull( variables.updatedAt ) ? "" : dateTimeFormat( variables.updatedAt, "iso" )
		};
	}

}
