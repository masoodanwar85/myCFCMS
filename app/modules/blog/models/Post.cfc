/**
 * A blog post.
 *
 * Flat and chronological, unlike a Page: a blog's structure is its timeline,
 * and categories rather than a hierarchy are how readers narrow it down.
 */
component accessors="true" {

	property name="id"              type="numeric";
	property name="siteId"          type="numeric";
	property name="title"           type="string";
	property name="slug"            type="string";
	property name="excerpt"         type="string";
	property name="content"         type="string";
	property name="status"          type="string";
	property name="metaTitle"       type="string";
	property name="metaDescription" type="string";
	property name="authorId"        type="numeric";
	property name="publishedAt";
	property name="createdAt";
	property name="updatedAt";

	// Filled in by the repository when a caller asks for them.
	property name="categories" type="array";

	this.STATUS_DRAFT     = "draft";
	this.STATUS_PUBLISHED = "published";
	this.STATUS_ARCHIVED  = "archived";

	function init(){
		variables.status     = this.STATUS_DRAFT;
		variables.content    = "";
		variables.categories = [];
		return this;
	}

	boolean function isPublished(){
		return variables.status == this.STATUS_PUBLISHED;
	}

	boolean function isDraft(){
		return variables.status == this.STATUS_DRAFT;
	}

	string function getEffectiveMetaTitle(){
		return len( trim( variables.metaTitle ?: "" ) ) ? variables.metaTitle : ( variables.title ?: "" );
	}

	/**
	 * The summary a listing shows.
	 *
	 * Falls back to the opening of the content with markup removed, so a post
	 * without a hand-written excerpt still reads sensibly in a list.
	 */
	string function getEffectiveExcerpt( numeric length = 200 ){
		if ( len( trim( variables.excerpt ?: "" ) ) ) {
			return variables.excerpt;
		}

		var text = trim( reReplace( variables.content ?: "", "<[^>]*>", " ", "all" ) );
		text     = trim( reReplace( text, "\s+", " ", "all" ) );

		return len( text ) > arguments.length ? left( text, arguments.length ) & "..." : text;
	}

	struct function getMemento(){
		// Assigned first: Adobe ColdFusion will not parse a member function
		// chained directly off a parenthesised `?:` expression.
		var filedUnder = variables.categories ?: [];

		return {
			"id"              : variables.id,
			"siteId"          : variables.siteId,
			"title"           : variables.title,
			"slug"            : variables.slug,
			"excerpt"         : getEffectiveExcerpt(),
			"content"         : variables.content ?: "",
			"status"          : variables.status,
			"metaTitle"       : variables.metaTitle ?: "",
			"metaDescription" : variables.metaDescription ?: "",
			"categories"      : filedUnder.map( ( c ) => c.getMemento() ),
			"publishedAt"     : isNull( variables.publishedAt ) ? "" : dateTimeFormat( variables.publishedAt, "iso" ),
			"createdAt"       : isNull( variables.createdAt ) ? "" : dateTimeFormat( variables.createdAt, "iso" ),
			"updatedAt"       : isNull( variables.updatedAt ) ? "" : dateTimeFormat( variables.updatedAt, "iso" )
		};
	}

}
