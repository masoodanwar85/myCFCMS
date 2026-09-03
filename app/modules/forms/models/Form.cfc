/**
 * A form: a name, some settings, and the fields an author gave it.
 *
 * `fields` is loaded on request rather than eagerly, the same way Blog loads a
 * post's categories — listing forms in the admin should not fetch every field
 * of every one.
 */
component accessors="true" {

	property name="id"              type="numeric";
	property name="siteId"          type="numeric";
	property name="name"            type="string";
	property name="slug"            type="string";
	property name="intro"           type="string";
	property name="submitLabel"     type="string";
	property name="successMessage"  type="string";
	property name="thankYouPath"    type="string";
	property name="recipientEmail"  type="string";

	/**
	 * Whether responses are kept in the database.
	 *
	 * Some forms exist only to send an email — and a form that collects
	 * something a client would rather not store should be able to say so
	 * rather than being told to delete rows afterwards.
	 */
	property name="storeSubmissions" type="boolean";

	property name="isActive"        type="boolean";
	property name="createdAt";
	property name="updatedAt";

	property name="fields" type="array";

	function init(){
		variables.isActive         = true;
		variables.storeSubmissions = true;
		variables.submitLabel      = "Send";
		variables.successMessage   = "Thank you. We have received your response.";
		variables.fields           = [];

		return this;
	}

	/**
	 * The first email field, if the form has one.
	 *
	 * What the notification replies to and what the inbox shows as the sender.
	 * A form need not ask for an address at all — not every form is a way of
	 * being contacted back — so this can be null and every caller must cope.
	 */
	function emailField(){
		for ( var field in variables.fields ) {
			if ( field.getFieldType() == "email" ) {
				return field;
			}
		}

		return;
	}

	struct function getMemento(){
		return {
			"id"             : variables.id,
			"siteId"         : variables.siteId,
			"name"           : variables.name,
			"slug"           : variables.slug,
			"intro"          : variables.intro ?: "",
			"submitLabel"    : variables.submitLabel,
			"successMessage" : variables.successMessage,
			"isActive"       : variables.isActive,
			"fields"         : variables.fields.map( ( f ) => f.getMemento() )
		};
	}

}
