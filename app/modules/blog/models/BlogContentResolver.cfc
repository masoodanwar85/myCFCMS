/**
 * Answers Core's routing question on behalf of the Blog module.
 *
 * Claims three shapes of URL under the blog's base path:
 *
 *     /blog                     the archive
 *     /blog/page/2              older posts
 *     /blog/category/{slug}     one category's archive
 *     /blog/category/{slug}/page/2
 *     /blog/{slug}              a single post
 *
 * Paging lives in the path rather than a query string: a resolver is handed the
 * path and nothing else, and a path is what a search engine and a person can
 * both read.
 *
 * Registered at a lower priority number than Pages, so `/blog` reaches the
 * archive even if a page happens to have that slug. Anything outside the base
 * path is declined, and Pages gets its turn.
 */
component singleton accessors="true" {

	property name="blogService" inject="BlogService@blog";
	property name="shortcodes"  inject="ShortcodeService@core";
	property name="settings"    inject="coldbox:moduleSettings:blog";
	property name="paginator"   inject="Paginator@core";

	function resolveContent( required numeric siteId, required string path ){
		var base = basePath();

		if ( !len( base ) ) {
			return;
		}

		// The archive itself.
		if ( arguments.path == base ) {
			return archive( arguments.siteId, 1 );
		}

		// Everything else must sit beneath the base path.
		if ( left( arguments.path, len( base ) + 1 ) != base & "/" ) {
			return;
		}

		var remainder = mid( arguments.path, len( base ) + 2, len( arguments.path ) );
		var paged     = splitPageSuffix( remainder );

		if ( !paged.isValid ) {
			return;
		}

		if ( !len( paged.path ) ) {
			return archive( arguments.siteId, paged.page );
		}

		if ( left( paged.path, 9 ) == "category/" ) {
			return categoryArchive( arguments.siteId, mid( paged.path, 10, len( paged.path ) ), paged.page );
		}

		// A single post has no pages; `/blog/some-post/page/2` is not a URL.
		if ( paged.page != 1 ) {
			return;
		}

		return singlePost( arguments.siteId, paged.path );
	}

	private function archive( required numeric siteId, required numeric page ){
		var total = blogService.countPublishedPosts( arguments.siteId );
		var pages = paginator.paginate( total = total, page = arguments.page, perPage = postsPerPage() );

		// Beyond the last page there is nothing to show. Serving page one under
		// a `/page/9` URL would be a different page's content at that address.
		if ( !pages.isValidPage ) {
			return;
		}

		return {
			"view" : "blog-index",
			"args" : {
				"posts"      : blogService.getPublishedPosts( arguments.siteId, pages.perPage, pages.offset ),
				"categories" : blogService.getCategoriesWithCounts( arguments.siteId ),
				"total"      : total,
				"basePath"   : basePath(),
				"category"   : "",
				"pagination" : pages,
				"pageBase"   : "/" & basePath()
			},
			"title"           : pages.page > 1 ? title() & " - page " & pages.page : title(),
			"metaDescription" : "",
			"statusCode"      : 200,
			"canonicalPath"   : basePath(),
			// Page 2 onward is a slice of a list, not a document in its own
			// right: its content changes as posts are added, and indexing it
			// competes with the posts themselves. Followed, so the crawler
			// still walks through to every post; not indexed.
			"robots"          : pages.page > 1 ? "noindex, follow" : ""
		};
	}

	private function categoryArchive(
		required numeric siteId,
		required string slug,
		required numeric page
	){
		var category = blogService.getCategoryBySlug( arguments.siteId, arguments.slug );

		// An unknown category is a missing page, not an empty list: an empty
		// list would tell a reader the category exists and happens to be bare.
		if ( isNull( category ) ) {
			return;
		}

		var total = blogService.countPublishedPostsInCategory( arguments.siteId, category.getId() );
		var pages = paginator.paginate( total = total, page = arguments.page, perPage = postsPerPage() );

		if ( !pages.isValidPage ) {
			return;
		}

		return {
			"view" : "blog-index",
			"args" : {
				"posts"      : blogService.getPublishedPostsInCategory(
					arguments.siteId, category.getId(), pages.perPage, pages.offset
				),
				"categories" : blogService.getCategoriesWithCounts( arguments.siteId ),
				"total"      : total,
				"basePath"   : basePath(),
				"category"   : category,
				"pagination" : pages,
				"pageBase"   : "/" & basePath() & "/category/" & category.getSlug()
			},
			"title"           : category.getName() & " - " & title(),
			"metaDescription" : category.getDescription() ?: "",
			"statusCode"      : 200,
			"canonicalPath"   : basePath() & "/category/" & category.getSlug(),
			"robots"          : pages.page > 1 ? "noindex, follow" : ""
		};
	}

	private function singlePost( required numeric siteId, required string slug ){
		var post = blogService.getPublishedPost( arguments.siteId, arguments.slug );

		if ( isNull( post ) ) {
			return;
		}

		// Same as Pages: stored as written, expanded on the way out.
		post.setContent(
			shortcodes.expand(
				content = post.getContent() ?: "",
				context = { "siteId" : arguments.siteId, "path" : basePath() & "/" & arguments.slug }
			)
		);

		return {
			"view" : "blog-post",
			"args" : {
				"post"     : post,
				"basePath" : basePath()
			},
			"title"           : post.getEffectiveMetaTitle(),
			"metaDescription" : len( post.getMetaDescription() ?: "" )
				? post.getMetaDescription()
				: post.getEffectiveExcerpt( 160 ),
			"statusCode"      : 200,
			"canonicalPath"   : basePath() & "/" & post.getSlug(),
			"contentType"     : "article",
			"publishedAt"     : post.getPublishedAt() ?: "",
			"modifiedAt"      : post.getUpdatedAt()
		};
	}

	/**
	 * Split a trailing `/page/N` off a path.
	 *
	 * @return `{ path, page, isValid }`. Invalid covers `/page/` with nothing
	 *         after it and `/page/abc` — neither is a page, so the caller
	 *         declines rather than guessing at page one.
	 */
	private struct function splitPageSuffix( required string path ){
		// Searching a leading-slash copy so that the archive's own paging —
		// where the remainder *is* "page/2" with nothing before it — is found
		// by the same rule as "category/x/page/2".
		var probe  = "/" & arguments.path;
		var marker = "/page/";
		var at     = findNoCase( marker, probe );

		if ( !at ) {
			return { "path" : arguments.path, "page" : 1, "isValid" : true };
		}

		var candidate = mid( probe, at + len( marker ), len( probe ) );

		// A page number and nothing after it. "page/2/extra" is not a URL.
		if ( !isValid( "integer", candidate ) || val( candidate ) < 1 || find( "/", candidate ) ) {
			return { "path" : "", "page" : 0, "isValid" : false };
		}

		return {
			"path"    : mid( probe, 2, max( 0, at - 2 ) ),
			"page"    : val( candidate ),
			"isValid" : true
		};
	}

	private string function basePath(){
		return reReplace( lCase( trim( settings.basePath ?: "blog" ) ), "^/+|/+$", "", "all" );
	}

	private numeric function postsPerPage(){
		return val( settings.postsPerPage ?: 10 );
	}

	private string function title(){
		return settings.archiveTitle ?: "Blog";
	}

}
