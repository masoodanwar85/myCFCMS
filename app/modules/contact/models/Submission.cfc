/**
 * A message someone sent through a contact form.
 *
 * Everything here except the status came from an anonymous visitor, so nothing
 * on this object should ever be treated as trustworthy markup. The admin
 * renders every field as escaped text.
 */
component accessors="true" {

	property name="id"        type="numeric";
	property name="siteId"    type="numeric";
	property name="formId"    type="numeric";
	property name="name"      type="string";
	property name="email"     type="string";
	property name="subject"   type="string";
	property name="message"   type="string";
	property name="status"    type="string";
	property name="ipAddress" type="string";
	property name="userAgent" type="string";
	property name="createdAt";
	property name="updatedAt";

	this.STATUS_NEW  = "new";
	this.STATUS_READ = "read";
	this.STATUS_SPAM = "spam";

	function init(){
		variables.status = this.STATUS_NEW;
		return this;
	}

	boolean function isNew(){
		return variables.status == this.STATUS_NEW;
	}

	boolean function isSpam(){
		return variables.status == this.STATUS_SPAM;
	}

	/**
	 * A short, single-line version of the message for a list.
	 */
	string function getSummary( numeric length = 90 ){
		var text = trim( reReplace( variables.message ?: "", "\s+", " ", "all" ) );

		return len( text ) > arguments.length ? left( text, arguments.length ) & "..." : text;
	}

	struct function getMemento(){
		return {
			"id"        : variables.id,
			"siteId"    : variables.siteId,
			"formId"    : variables.formId,
			"name"      : variables.name,
			"email"     : variables.email,
			"subject"   : variables.subject ?: "",
			"message"   : variables.message,
			"status"    : variables.status,
			"createdAt" : isNull( variables.createdAt ) ? "" : dateTimeFormat( variables.createdAt, "iso" )
		};
	}

}
