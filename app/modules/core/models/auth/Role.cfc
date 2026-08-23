/**
 * A named bundle of permissions, owned by one site.
 *
 * Roles are per-tenant: each client shapes its own. The permissions a role
 * grants come from the global catalogue — see Permission.
 */
component accessors="true" {

	property name="id"          type="numeric";
	property name="siteId"      type="numeric";
	property name="name"        type="string";
	property name="slug"        type="string";
	property name="description" type="string";
	property name="createdAt";
	property name="updatedAt";

	struct function getMemento(){
		return {
			"id"          : variables.id,
			"siteId"      : variables.siteId,
			"name"        : variables.name,
			"slug"        : variables.slug,
			"description" : variables.description ?: "",
			"createdAt"   : isNull( variables.createdAt ) ? "" : dateTimeFormat( variables.createdAt, "iso" ),
			"updatedAt"   : isNull( variables.updatedAt ) ? "" : dateTimeFormat( variables.updatedAt, "iso" )
		};
	}

}
