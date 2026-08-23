/**
 * A hostname that points at a Site.
 *
 * A site may own several (client.com, www.client.com, staging.client.com);
 * a hostname may only ever belong to one site — enforced by a unique index
 * on `site_domains.domain`, not by application code alone.
 */
component accessors="true" {

	property name="id"        type="numeric";
	property name="siteId"    type="numeric";
	property name="domain"    type="string";
	property name="isPrimary" type="boolean";
	property name="isActive"  type="boolean";
	property name="createdAt";
	property name="updatedAt";

	function init(){
		variables.isPrimary = false;
		variables.isActive  = true;
		return this;
	}

	struct function getMemento(){
		return {
			"id"        : variables.id,
			"siteId"    : variables.siteId,
			"domain"    : variables.domain,
			"isPrimary" : variables.isPrimary,
			"isActive"  : variables.isActive,
			"createdAt" : isNull( variables.createdAt ) ? "" : dateTimeFormat( variables.createdAt, "iso" ),
			"updatedAt" : isNull( variables.updatedAt ) ? "" : dateTimeFormat( variables.updatedAt, "iso" )
		};
	}

}
