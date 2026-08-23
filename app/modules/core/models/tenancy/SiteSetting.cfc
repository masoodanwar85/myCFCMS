/**
 * One tenant-scoped configuration value.
 *
 * Key/value on purpose: settings differ per site and grow per module, and we
 * are not going to widen a table every time a module needs a new toggle.
 * Values are stored as text; callers own their interpretation.
 */
component accessors="true" {

	property name="id"           type="numeric";
	property name="siteId"       type="numeric";
	property name="settingKey"   type="string";
	property name="settingValue" type="string";
	property name="createdAt";
	property name="updatedAt";

	struct function getMemento(){
		return {
			"id"           : variables.id,
			"siteId"       : variables.siteId,
			"settingKey"   : variables.settingKey,
			"settingValue" : variables.settingValue ?: "",
			"createdAt"    : isNull( variables.createdAt ) ? "" : dateTimeFormat( variables.createdAt, "iso" ),
			"updatedAt"    : isNull( variables.updatedAt ) ? "" : dateTimeFormat( variables.updatedAt, "iso" )
		};
	}

}
