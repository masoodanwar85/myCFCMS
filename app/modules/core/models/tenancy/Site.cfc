/**
 * A tenant website.
 *
 * A plain state object: no persistence, no rendering, no request awareness.
 * That keeps it usable unchanged by server-rendered views, the future REST
 * API and any later GraphQL layer.
 */
component accessors="true" {

	property name="id"        type="numeric";
	property name="name"      type="string";
	property name="slug"      type="string";
	property name="status"    type="string";
	property name="timezone"  type="string";
	property name="locale"    type="string";
	property name="createdAt";
	property name="updatedAt";

	// The only statuses Group 1 recognises. Mirrored by a CHECK constraint on `sites`.
	this.STATUS_ACTIVE   = "active";
	this.STATUS_INACTIVE = "inactive";

	function init(){
		variables.status   = this.STATUS_ACTIVE;
		variables.timezone = "UTC";
		variables.locale   = "en_US";
		return this;
	}

	boolean function isActive(){
		return variables.status == this.STATUS_ACTIVE;
	}

	/**
	 * Serialisation-friendly representation, for views and future API responses.
	 */
	struct function getMemento(){
		return {
			"id"        : variables.id,
			"name"      : variables.name,
			"slug"      : variables.slug,
			"status"    : variables.status,
			"timezone"  : variables.timezone,
			"locale"    : variables.locale,
			"createdAt" : isNull( variables.createdAt ) ? "" : dateTimeFormat( variables.createdAt, "iso" ),
			"updatedAt" : isNull( variables.updatedAt ) ? "" : dateTimeFormat( variables.updatedAt, "iso" )
		};
	}

}
