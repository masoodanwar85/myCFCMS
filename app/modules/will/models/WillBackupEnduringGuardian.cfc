/**
 * A backup enduring guardian on a will submission.
 */
component accessors="true" {

	property name="id"           type="numeric";
	property name="siteId"       type="numeric";
	property name="submissionId" type="numeric";
	property name="sortOrder"    type="numeric";
	property name="egName"       type="string";
	property name="egAddress"    type="string";
	property name="egEmail"      type="string";
	property name="egPhone"      type="string";
	property name="egDirections" type="string";
	property name="createdAt";

	function init(){
		variables.sortOrder = 1;
		return this;
	}

}
