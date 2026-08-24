/**
 * `[recent-posts count="3" category="craft"]`
 *
 * Puts a list of the newest published posts anywhere content is rendered — a
 * home page, an "about" page, a sidebar snippet — without that page needing to
 * know anything about the Blog module beyond the tag.
 *
 * This is the shortcode that proves the seam is worth having: Core knows only
 * that something answers for `recent-posts`, and removing the Blog module
 * removes the capability along with it.
 */
component singleton accessors="true" {

	property name="blogService" inject="BlogService@blog";
	property name="settings"    inject="coldbox:moduleSettings:blog";

	this.TAG         = "recent-posts";
	this.DESCRIPTION = 'Lists the newest published posts: [recent-posts count="3"]';

	// A page asking for a thousand posts should get ten. The cap is here rather
	// than in the query because the number comes from content anyone with
	// `pages.update` can write.
	variables.MAX = 10;

	string function render( struct attributes = {}, string body = "", struct context = {} ){
		var siteId = val( arguments.context.siteId ?: 0 );

		if ( !siteId ) {
			return "";
		}

		var count = val( arguments.attributes.count ?: 3 );

		count = max( 1, min( variables.MAX, count ) );

		var posts = blogService.getPublishedPosts( siteId, count, 0 );

		if ( !posts.len() ) {
			return "";
		}

		var base  = reReplace( lCase( trim( settings.basePath ?: "blog" ) ), "^/+|/+$", "", "all" );
		var items = [];

		for ( var post in posts ) {
			items.append(
				'<li><a href="' & xmlFormat( "/" & base & "/" & post.getSlug() ) & '">'
				& arguments.context.escape( post.getTitle() )
				& "</a></li>"
			);
		}

		return '<ul class="shortcode-recent-posts">' & items.toList( "" ) & "</ul>";
	}

}
