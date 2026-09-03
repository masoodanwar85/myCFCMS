/**
 * A contact form a site publishes.
 */
component accessors="true" {

	property name="id"             type="numeric";
	property name="siteId"         type="numeric";
	property name="name"           type="string";
	property name="slug"           type="string";
	property name="intro"          type="string";
	property name="recipientEmail" type="string";
	property name="successMessage" type="string";

	/**
	 * Where to send the visitor after a successful send, or empty to leave them
	 * on the page the form was embedded in.
	 *
	 * Site-relative only. An open redirect on a public form is how a phishing
	 * page borrows a client's domain; `ContactService` is what enforces it.
	 */
	property name="thankYouPath"   type="string";
	property name="isActive"       type="boolean";
	property name="createdAt";
	property name="updatedAt";

	function init(){
		variables.isActive       = true;
		variables.successMessage = "Thank you. We will be in touch.";
		return this;
	}

	struct function getMemento(){
		return {
			"id"             : variables.id,
			"siteId"         : variables.siteId,
			"name"           : variables.name,
			"slug"           : variables.slug,
			"intro"          : variables.intro ?: "",
			"recipientEmail" : variables.recipientEmail ?: "",
			"successMessage" : variables.successMessage,
			"isActive"       : variables.isActive
		};
	}

}
