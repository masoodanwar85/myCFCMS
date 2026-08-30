/**
 * An additional attorney on a will submission.
 */
component accessors="true" {

	property name="id"           type="numeric";
	property name="siteId"       type="numeric";
	property name="submissionId" type="numeric";
	property name="sortOrder"    type="numeric";
	property name="poaName"      type="string";
	property name="poaAddress"   type="string";
	property name="poaEmail"     type="string";
	property name="poaPhone"     type="string";
	property name="poaCommence"  type="string";
	property name="createdAt";

	function init(){
		variables.sortOrder = 1;
		return this;
	}

}
