/**
 * A content page belonging to one site.
 *
 * State only: no persistence, no rendering, no request awareness — so the same
 * object serves a server-rendered view, a REST response and a later GraphQL
 * type without change.
 */
component accessors="true" {

	property name="id"              type="numeric";
	property name="siteId"          type="numeric";
	property name="parentId"        type="numeric";
	property name="title"           type="string";
	property name="slug"            type="string";
	property name="path"            type="string";
	property name="status"          type="string";
	property name="content"         type="string";
	property name="metaTitle"       type="string";
	property name="metaDescription" type="string";
	property name="sortOrder"       type="numeric";
	property name="publishedAt";
	property name="createdBy"       type="numeric";
	property name="updatedBy"       type="numeric";
	property name="createdAt";
	property name="updatedAt";

	this.STATUS_DRAFT     = "draft";
	this.STATUS_PUBLISHED = "published";
	this.STATUS_ARCHIVED  = "archived";

	function init(){
		variables.status    = this.STATUS_DRAFT;
		variables.sortOrder = 0;
		variables.content   = "";
		return this;
	}

	boolean function isPublished(){
		return variables.status == this.STATUS_PUBLISHED;
	}

	boolean function isDraft(){
		return variables.status == this.STATUS_DRAFT;
	}

	boolean function isArchived(){
		return variables.status == this.STATUS_ARCHIVED;
	}

	/**
	 * Detach from any parent, making this a top-level page.
	 *
	 * An explicit method rather than `setParentId( null )`: passing a null
	 * through a generated setter is not dependable across CFML engines.
	 */
	function clearParent(){
		structDelete( variables, "parentId" );
		return this;
	}

	/**
	 * A page with no parent sits at the top of the site's tree.
	 */
	boolean function isRoot(){
		return isNull( variables.parentId );
	}

	/**
	 * How deep in the tree this page sits. Root pages are depth 0.
	 */
	numeric function getDepth(){
		return listLen( variables.path ?: "", "/" ) - 1;
	}

	/**
	 * The title a browser tab and a search result should show.
	 *
	 * Falls back to the page title, so a page is never published without one.
	 */
	string function getEffectiveMetaTitle(){
		return len( trim( variables.metaTitle ?: "" ) ) ? variables.metaTitle : ( variables.title ?: "" );
	}

	struct function getMemento(){
		return {
			"id"              : variables.id,
			"siteId"          : variables.siteId,
			"parentId"        : isNull( variables.parentId ) ? "" : variables.parentId,
			"title"           : variables.title,
			"slug"            : variables.slug,
			"path"            : variables.path,
			"status"          : variables.status,
			"content"         : variables.content ?: "",
			"metaTitle"       : variables.metaTitle ?: "",
			"metaDescription" : variables.metaDescription ?: "",
			"sortOrder"       : variables.sortOrder,
			"publishedAt"     : isNull( variables.publishedAt ) ? "" : dateTimeFormat( variables.publishedAt, "iso" ),
			"createdAt"       : isNull( variables.createdAt ) ? "" : dateTimeFormat( variables.createdAt, "iso" ),
			"updatedAt"       : isNull( variables.updatedAt ) ? "" : dateTimeFormat( variables.updatedAt, "iso" )
		};
	}

}
