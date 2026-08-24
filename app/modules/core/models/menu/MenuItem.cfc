/**
 * One entry in a menu.
 *
 * An item points at content or at a URL, and the difference matters. A
 * `content` item stores what it links to — the owning module plus the row id —
 * and its address is resolved at render time, so renaming a page moves every
 * menu that points at it. A `url` item stores the address itself, for anything
 * the CMS does not own.
 *
 * `href` and `isAvailable` are filled in by MenuService after resolution. An
 * item whose content has been deleted comes back unavailable rather than
 * pointing at a 404, and the service drops it from the rendered menu.
 */
component accessors="true" {

	property name="id"          type="numeric";
	property name="menuId"      type="numeric";
	property name="siteId"      type="numeric";
	property name="parentId"    type="numeric";
	property name="label"       type="string";
	property name="linkType"    type="string";
	property name="contentType" type="string";
	property name="contentId"   type="numeric";
	property name="url"         type="string";
	property name="target"      type="string";
	property name="sortOrder"   type="numeric";
	property name="createdAt";
	property name="updatedAt";

	// Filled in at render time, not stored.
	property name="href"        type="string";
	property name="isAvailable" type="boolean";
	property name="children"    type="array";

	function init(){
		variables.children    = [];
		variables.href        = "";
		variables.isAvailable = true;
		variables.linkType    = "url";
		variables.contentId   = 0;
		variables.contentType = "";
		variables.target      = "";
		variables.sortOrder   = 0;
		return this;
	}

	boolean function isContentLink(){
		return ( variables.linkType ?: "url" ) == "content";
	}

	boolean function hasChildren(){
		return variables.children.len() > 0;
	}

	/**
	 * What the editor typed, or a description of what this points at.
	 *
	 * Used by the admin list so an item reads sensibly before it is resolved.
	 */
	string function getLinkDescription(){
		return isContentLink()
			? ( variables.contentType ?: "" ) & "##" & ( variables.contentId ?: "" )
			: ( variables.url ?: "" );
	}

	/**
	 * An external link leaves the site, and `rel` should say so on anything
	 * that also opens in a new tab.
	 */
	boolean function isExternal(){
		return !isContentLink() && reFindNoCase( "^https?://", variables.url ?: "" ) > 0;
	}

}
