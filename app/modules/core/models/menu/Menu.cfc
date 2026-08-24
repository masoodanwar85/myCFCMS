/**
 * One named list of links belonging to a site.
 *
 * A site usually has more than one: `primary` in the header, `footer` at the
 * bottom. The slug is the contract with the theme, which asks for a menu by
 * name and renders whatever it finds.
 */
component accessors="true" {

	property name="id"        type="numeric";
	property name="siteId"    type="numeric";
	property name="name"      type="string";
	property name="slug"      type="string";
	property name="createdAt";
	property name="updatedAt";

	// Populated by MenuService when a whole menu is read; empty otherwise, so a
	// caller that only wanted the record does not pay for the item queries.
	property name="items" type="array";

	function init(){
		variables.items = [];
		return this;
	}

	boolean function isEmpty(){
		return !variables.items.len();
	}

}
