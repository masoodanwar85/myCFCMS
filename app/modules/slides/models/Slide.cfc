/**
 * One hero slide, scoped to a site.
 *
 * The background image and the overlay HTML are tenant data. Where that HTML
 * sits on the image is a display switch (`hAlign` / `vAlign`), not markup an
 * author has to fight the editor for.
 */
component accessors="true" {

	property name="id"          type="numeric";
	property name="siteId"      type="numeric";
	property name="imageUrl"    type="string";
	property name="imageAlt"    type="string";
	property name="overlayHtml" type="string";
	property name="hAlign"      type="string";
	property name="vAlign"      type="string";
	property name="sortOrder"   type="numeric";
	property name="isPublished" type="boolean";
	property name="createdAt";
	property name="updatedAt";

	this.H_ALIGNS = "left,center,right";
	this.V_ALIGNS = "top,middle,bottom";

	function init(){
		variables.imageUrl    = "";
		variables.imageAlt    = "";
		variables.overlayHtml = "";
		variables.hAlign      = "left";
		variables.vAlign      = "middle";
		variables.sortOrder   = 0;
		variables.isPublished = false;
		return this;
	}

	/**
	 * A one-line label for admin lists: the overlay with markup stripped, or
	 * "Slide" when the overlay is empty.
	 */
	string function getLabel(){
		var text = trim( reReplace( variables.overlayHtml ?: "", "<[^>]*>", " ", "all" ) );
		text     = trim( reReplace( text, "\s+", " ", "all" ) );

		if ( !len( text ) ) {
			return "Slide";
		}

		return len( text ) > 80 ? left( text, 80 ) & "..." : text;
	}

	struct function getMemento(){
		return {
			"id"          : variables.id,
			"siteId"      : variables.siteId,
			"imageUrl"    : variables.imageUrl ?: "",
			"imageAlt"    : variables.imageAlt ?: "",
			"overlayHtml" : variables.overlayHtml ?: "",
			"hAlign"      : variables.hAlign ?: "left",
			"vAlign"      : variables.vAlign ?: "middle",
			"sortOrder"   : variables.sortOrder ?: 0,
			"isPublished" : variables.isPublished ? true : false,
			"createdAt"   : isNull( variables.createdAt ) ? "" : dateTimeFormat( variables.createdAt, "iso" ),
			"updatedAt"   : isNull( variables.updatedAt ) ? "" : dateTimeFormat( variables.updatedAt, "iso" )
		};
	}

}
