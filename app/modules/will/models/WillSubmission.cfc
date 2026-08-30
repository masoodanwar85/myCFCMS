/**
 * One completed will questionnaire, scoped to a site.
 *
 * Field names match the form prefixes (`wm_`, `ex_`, `poa_`, `eg_`, `da_`).
 * Repeating groups live on their own entities, not here.
 */
component accessors="true" {

	property name="id"                 type="numeric";
	property name="siteId"             type="numeric";
	property name="userId";
	property name="status"             type="string";
	property name="currentStep";
	property name="wmFullname"         type="string";
	property name="wmDob";
	property name="wmMarital"          type="string";
	property name="wmAddress"          type="string";
	property name="wmEmail"            type="string";
	property name="wmPhone"            type="string";
	property name="exName"             type="string";
	property name="exAddress"          type="string";
	property name="exRelationship"     type="string";
	property name="exEmail"            type="string";
	property name="exPhone"            type="string";
	property name="exCanChargeFees"    type="boolean";
	property name="exActMode"          type="string";
	property name="guardName"          type="string";
	property name="guardAddress"       type="string";
	property name="guardChildren"      type="string";
	property name="estateResidue"      type="string";
	property name="poaName"            type="string";
	property name="poaAddress"         type="string";
	property name="poaEmail"           type="string";
	property name="poaPhone"           type="string";
	property name="poaCommence"        type="string";
	property name="poaActMode"         type="string";
	property name="egName"             type="string";
	property name="egAddress"          type="string";
	property name="egEmail"            type="string";
	property name="egPhone"            type="string";
	property name="egDirections"       type="string";
	property name="egActMode"          type="string";
	property name="bodyDisposal"       type="string";
	property name="bodyInstructions"   type="string";
	property name="daIncludeClauses"   type="string";
	property name="daInstructions"     type="string";
	property name="daNotes"            type="string";
	property name="consentAccepted"    type="boolean";
	property name="consentAcceptedAt";
	property name="ipAddress"          type="string";
	property name="userAgent"          type="string";
	property name="notes"              type="string";
	property name="createdAt";
	property name="updatedAt";

	this.STATUS_SUBMITTED = "submitted";

	function init(){
		variables.status          = this.STATUS_SUBMITTED;
		variables.exCanChargeFees = false;
		variables.consentAccepted = false;
		return this;
	}

	function getUserId(){
		return variables.userId ?: javacast( "null", "" );
	}

	function getCurrentStep(){
		return variables.currentStep ?: javacast( "null", "" );
	}

	function getConsentAcceptedAt(){
		return variables.consentAcceptedAt ?: javacast( "null", "" );
	}

}
