/**
 * Lets a menu item point at the blog archive or a single post.
 *
 * The archive is offered as `blog.archive` with a fixed id of 0: there is only
 * ever one, and it has no row of its own. Giving it a type at all — rather than
 * telling an editor to type `/blog` as a URL — means it follows the module's
 * `basePath` setting if that is ever changed.
 */
component singleton accessors="true" {

	property name="postRepository" inject="PostRepository@blog";
	property name="settings"       inject="coldbox:moduleSettings:blog";

	this.ARCHIVE = "blog.archive";
	this.POST    = "blog.post";

	array function getLinkTargets( required numeric siteId ){
		var targets = [
			{
				"type"  : this.ARCHIVE,
				"id"    : 0,
				"label" : settings.archiveTitle ?: "Blog",
				"path"  : basePath(),
				"group" : "Blog"
			}
		];

		for ( var post in postRepository.findPublished( arguments.siteId, 500, 0 ) ) {
			targets.append( {
				"type"  : this.POST,
				"id"    : post.getId(),
				"label" : post.getTitle(),
				"path"  : basePath() & "/" & post.getSlug(),
				"group" : "Blog posts"
			} );
		}

		return targets;
	}

	function resolveLinkTarget( required numeric siteId, required string type, required numeric id ){
		if ( arguments.type == this.ARCHIVE ) {
			return {
				"label" : settings.archiveTitle ?: "Blog",
				"path"  : basePath()
			};
		}

		if ( arguments.type != this.POST ) {
			return;
		}

		var post = postRepository.findById( arguments.id );

		if ( isNull( post ) || post.getSiteId() != arguments.siteId || post.getStatus() != "published" ) {
			return;
		}

		return {
			"label" : post.getTitle(),
			"path"  : basePath() & "/" & post.getSlug()
		};
	}

	private string function basePath(){
		return reReplace( lCase( trim( settings.basePath ?: "blog" ) ), "^/+|/+$", "", "all" );
	}

}
