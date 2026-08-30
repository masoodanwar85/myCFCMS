/**
 * A substitute executor on a will submission.
 */
component accessors="true" {

	property name="id"              type="numeric";
	property name="siteId"          type="numeric";
	property name="submissionId"    type="numeric";
	property name="sortOrder"       type="numeric";
	property name="exName"          type="string";
	property name="exAddress"       type="string";
	property name="exRelationship"  type="string";
	property name="exEmail"         type="string";
	property name="exPhone"         type="string";
	property name="exCanChargeFees" type="boolean";
	property name="createdAt";

	function init(){
		variables.sortOrder       = 1;
		variables.exCanChargeFees = false;
		return this;
	}

}
