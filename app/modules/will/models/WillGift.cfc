/**
 * A specific gift on a will submission.
 */
component accessors="true" {

	property name="id"              type="numeric";
	property name="siteId"          type="numeric";
	property name="submissionId"    type="numeric";
	property name="sortOrder"       type="numeric";
	property name="giftItem"        type="string";
	property name="giftBeneficiary" type="string";
	property name="createdAt";

	function init(){
		variables.sortOrder = 1;
		return this;
	}

}
