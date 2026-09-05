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

	/**
	 * Whether the theme prints this page's title as a heading above the content.
	 *
	 * A display switch, not a second title. The title is still the browser tab,
	 * the menu label, the breadcrumb and the `<title>` tag when this is off —
	 * only the on-page `<h1>` goes away, for pages whose content supplies its
	 * own headline.
	 */
	property name="showHeading"     type="boolean";

	/**
	 * A template in the site's theme, or empty for the ordinary `page` view.
	 *
	 * A name, never code. See the migration for why that distinction is the
	 * whole point of the feature.
	 */
	property name="template"        type="string";
	property name="metaTitle"       type="string";
	property name="metaDescription" type="string";
	property name="sortOrder"       type="numeric";

	// SEO and social. All optional: an empty value means "use the site
	// default", which is what SeoService supplies.
	property name="metaKeywords"     type="string";
	property name="canonicalUrl"     type="string";
	property name="robotsIndex"      type="boolean";
	property name="robotsFollow"     type="boolean";
	property name="ogTitle"          type="string";
	property name="ogDescription"    type="string";
	property name="ogImage"          type="string";
	property name="ogType"           type="string";
	property name="twitterCard"      type="string";

	// Sitemap.
	property name="sitemapInclude"    type="boolean";
	property name="sitemapPriority"   type="numeric";
	property name="sitemapChangefreq" type="string";

	// Scheduling.
	property name="publishFrom";
	property name="publishUntil";

	// Raw markup, guarded by `content.unfiltered`.
	property name="headMarkup" type="string";
	property name="bodyMarkup" type="string";
	property name="jsonLd"     type="string";
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

		// The behaviour every page had before these options existed.
		variables.showHeading = true;
		variables.template    = "";

		// The behaviour that existed before these fields did, so a page created
		// without touching the SEO tab presents exactly as it always has.
		variables.robotsIndex       = true;
		variables.robotsFollow      = true;
		variables.ogType            = "website";
		variables.twitterCard       = "summary_large_image";
		variables.sitemapInclude    = true;
		variables.sitemapPriority   = 0.5;
		variables.sitemapChangefreq = "weekly";

		return this;
	}

	boolean function isPublished(){
		return variables.status == this.STATUS_PUBLISHED;
	}

	/**
	 * Is this page inside its publication window right now?
	 *
	 * Separate from `isPublished()` on purpose. "Published" is an editor's
	 * decision and is what the admin shows; "live" is that decision *plus* the
	 * clock. A page scheduled for next Tuesday is published and not live, and
	 * conflating the two would either hide it from its own author or serve it
	 * early.
	 */
	boolean function isLive(){
		if ( !isPublished() ) {
			return false;
		}

		if ( !isNull( variables.publishFrom ) && dateCompare( now(), variables.publishFrom ) < 0 ) {
			return false;
		}

		if ( !isNull( variables.publishUntil ) && dateCompare( now(), variables.publishUntil ) > 0 ) {
			return false;
		}

		return true;
	}

	/**
	 * Why this page is not live, for the admin list. Empty when it is.
	 */
	string function getScheduleState(){
		if ( !isPublished() ) {
			return "";
		}

		if ( !isNull( variables.publishFrom ) && dateCompare( now(), variables.publishFrom ) < 0 ) {
			return "scheduled";
		}

		if ( !isNull( variables.publishUntil ) && dateCompare( now(), variables.publishUntil ) > 0 ) {
			return "expired";
		}

		return "";
	}

	/**
	 * The `robots` directive this page asks for, or an empty string when it
	 * wants the default.
	 *
	 * Only says something when it has something to say: emitting
	 * `index, follow` on every page is noise, because it is what a crawler does
	 * anyway in the absence of a tag.
	 */
	string function getRobotsDirective(){
		// `isNull`, not `?:`. ColdFusion's elvis operator falls through on any
		// falsy value, so `variables.robotsIndex ?: true` reads a stored
		// `false` as `true` — and a page an editor had marked `noindex`
		// rendered `index` while being correctly dropped from the sitemap. The
		// two disagreed, and only the sitemap was right.
		var index  = ( isNull( variables.robotsIndex ) || variables.robotsIndex ) ? "index" : "noindex";
		var follow = ( isNull( variables.robotsFollow ) || variables.robotsFollow ) ? "follow" : "nofollow";

		if ( index == "index" && follow == "follow" ) {
			return "";
		}

		return index & ", " & follow;
	}

	boolean function isDraft(){
		return variables.status == this.STATUS_DRAFT;
	}

	boolean function isArchived(){
		return variables.status == this.STATUS_ARCHIVED;
	}

	/**
	 * Unset a date property.
	 *
	 * `setPublishFrom( "" )` would store an empty string, and passing a null
	 * through a generated setter is not dependable across CFML engines — the
	 * same reason `clearParent()` exists. An editor removing a schedule has to
	 * actually remove it, or the page stays stuck outside its own window.
	 */
	function clearDate( required string property ){
		if ( listFindNoCase( "publishFrom,publishUntil,publishedAt", arguments.property ) ) {
			structDelete( variables, arguments.property );
		}

		return this;
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
