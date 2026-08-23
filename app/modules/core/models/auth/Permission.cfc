/**
 * One thing the software can do, e.g. `users.create`.
 *
 * Global, not per-tenant: permissions describe capabilities of the code and are
 * registered by Core and by feature modules. Clients compose them into roles
 * rather than inventing them.
 */
component accessors="true" {

	property name="id"          type="numeric";
	property name="slug"        type="string";
	property name="name"        type="string";
	property name="description" type="string";
	property name="createdAt";
	property name="updatedAt";

	struct function getMemento(){
		return {
			"id"          : variables.id,
			"slug"        : variables.slug,
			"name"        : variables.name,
			"description" : variables.description ?: "",
			"createdAt"   : isNull( variables.createdAt ) ? "" : dateTimeFormat( variables.createdAt, "iso" ),
			"updatedAt"   : isNull( variables.updatedAt ) ? "" : dateTimeFormat( variables.updatedAt, "iso" )
		};
	}

}
