/**
 * One response to a form.
 *
 * `answers` is the record of what was asked as well as what was said: an array
 * of `{ key, label, type, value }`. Stored that way so an old response stays
 * readable after the form has been rewritten — a label keyed to a live field
 * row would start displaying yesterday's answer under today's question.
 */
component accessors="true" {

	property name="id"          type="numeric";
	property name="siteId"      type="numeric";
	property name="formId"      type="numeric";
	property name="answers"     type="array";
	property name="senderEmail" type="string";

	/**
	 * A one-line description for the inbox list, taken from the first
	 * meaningful answer. Denormalised because building it means walking the
	 * answers, and the list shows twenty-five at a time.
	 */
	property name="summary"     type="string";

	property name="status"      type="string";
	property name="ipAddress"   type="string";
	property name="userAgent"   type="string";
	property name="createdAt";
	property name="updatedAt";

	this.STATUS_NEW  = "new";
	this.STATUS_READ = "read";
	this.STATUS_SPAM = "spam";

	function init(){
		variables.status  = this.STATUS_NEW;
		variables.answers = [];

		return this;
	}

	boolean function isNewMessage(){
		return variables.status == this.STATUS_NEW;
	}

	/**
	 * An answer's value as text, for a list or an email.
	 *
	 * A multi-value answer is stored as an array; joining is done here so no
	 * caller has to remember which types can hold several.
	 */
	string function displayValue( required struct answer ){
		var value = arguments.answer.value ?: "";

		return isArray( value ) ? arrayToList( value, ", " ) : toString( value );
	}

	struct function getMemento(){
		return {
			"id"          : variables.id,
			"formId"      : variables.formId,
			"answers"     : variables.answers,
			"senderEmail" : variables.senderEmail ?: "",
			"summary"     : variables.summary ?: "",
			"status"      : variables.status,
			"createdAt"   : isNull( variables.createdAt ) ? "" : dateTimeFormat( variables.createdAt, "iso" )
		};
	}

}
