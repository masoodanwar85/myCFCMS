/**
 * Blog use cases.
 *
 * Same shape as PageService: validate, sanitise, orchestrate; render nothing,
 * know no HTTP. Content is sanitised unless the caller says the author holds
 * `content.unfiltered`.
 */
component singleton accessors="true" {

	property name="postRepository"     inject="PostRepository@blog";
	property name="slugifier"        inject="Slugifier@core";
	property name="categoryRepository" inject="CategoryRepository@blog";
	property name="siteRepository"     inject="SiteRepository@core";
	property name="userRepository"     inject="UserRepository@core";
	property name="sanitizer"          inject="ContentSanitizer@core";
	property name="redirects"          inject="RedirectService@core";
	property name="settings"           inject="coldbox:moduleSettings:blog";
	property name="wirebox"            inject="wirebox";

	/* ---------------------------------------------------------------------
	 * Posts
	 * ------------------------------------------------------------------ */

	/**
	 * @allowUnfilteredHtml Skip sanitising. The caller checks the permission.
	 *
	 * @throws Blog.SiteNotFound
	 * @throws Blog.InvalidPost
	 * @throws Blog.SlugAlreadyExists
	 * @throws Blog.InvalidAuthor
	 */
	blog.models.Post function createPost(
		required numeric siteId,
		required string title,
		string slug            = "",
		string excerpt         = "",
		string content         = "",
		string status          = "draft",
		string metaTitle       = "",
		string metaDescription = "",
		array categoryIds      = [],
		numeric authorId,
		boolean allowUnfilteredHtml = false,
		// Defaults to the behaviour posts had before the option existed.
		boolean showHeading    = true
	){
		if ( isNull( siteRepository.findById( arguments.siteId ) ) ) {
			throw( type = "Blog.SiteNotFound", message = "No site with id [#arguments.siteId#]." );
		}

		var postTitle = trim( arguments.title );

		if ( !len( postTitle ) ) {
			throw( type = "Blog.InvalidPost", message = "A post requires a title." );
		}

		if ( !isValidStatus( arguments.status ) ) {
			throw(
				type    = "Blog.InvalidPost",
				message = "Unknown post status [#arguments.status#]. Expected `draft`, `published` or `archived`."
			);
		}

		var postSlug = len( trim( arguments.slug ) ) ? slugify( arguments.slug ) : slugify( postTitle );

		if ( !len( postSlug ) ) {
			throw(
				type    = "Blog.InvalidPost",
				message = "Could not derive a usable slug from [#postTitle#]. Provide one explicitly."
			);
		}

		if ( postRepository.existsBySlug( arguments.siteId, postSlug ) ) {
			throw( type = "Blog.SlugAlreadyExists", message = "This site already has a post at [#postSlug#]." );
		}

		if ( !isNull( arguments.authorId ) ) {
			requireAuthorForSite( arguments.authorId, arguments.siteId );
		}

		var post = wirebox
			.getInstance( "Post@blog" )
			.setSiteId( arguments.siteId )
			.setTitle( postTitle )
			.setSlug( postSlug )
			.setExcerpt( trim( arguments.excerpt ) )
			.setContent( sanitizer.sanitize( arguments.content, arguments.allowUnfilteredHtml ) )
			.setStatus( arguments.status )
			.setMetaTitle( trim( arguments.metaTitle ) )
			.setMetaDescription( trim( arguments.metaDescription ) )
			.setShowHeading( arguments.showHeading );

		if ( !isNull( arguments.authorId ) ) {
			post.setAuthorId( arguments.authorId );
		}

		if ( post.isPublished() ) {
			post.setPublishedAt( now() );
		}

		var created = postRepository.create( post );

		syncCategories( created.getId(), arguments.siteId, arguments.categoryIds );

		return created;
	}

	/**
	 * @throws Blog.PostNotFound
	 * @throws Blog.SlugAlreadyExists
	 */
	blog.models.Post function updatePost(
		required numeric postId,
		string title,
		string slug,
		string excerpt,
		string content,
		string metaTitle,
		string metaDescription,
		array categoryIds,
		boolean allowUnfilteredHtml = false,
		boolean showHeading
	){
		var post    = requirePost( arguments.postId );
		var oldSlug = post.getSlug();

		if ( !isNull( arguments.title ) ) {
			if ( !len( trim( arguments.title ) ) ) {
				throw( type = "Blog.InvalidPost", message = "A post requires a title." );
			}
			post.setTitle( trim( arguments.title ) );
		}

		if ( !isNull( arguments.slug ) && len( trim( arguments.slug ) ) ) {
			var newSlug = slugify( arguments.slug );

			if ( !len( newSlug ) ) {
				throw( type = "Blog.InvalidPost", message = "[#arguments.slug#] is not a usable slug." );
			}

			if ( newSlug != post.getSlug() && postRepository.existsBySlug( post.getSiteId(), newSlug ) ) {
				throw( type = "Blog.SlugAlreadyExists", message = "This site already has a post at [#newSlug#]." );
			}

			post.setSlug( newSlug );
		}

		if ( !isNull( arguments.excerpt ) ) {
			post.setExcerpt( trim( arguments.excerpt ) );
		}
		if ( !isNull( arguments.content ) ) {
			post.setContent( sanitizer.sanitize( arguments.content, arguments.allowUnfilteredHtml ) );
		}
		if ( !isNull( arguments.metaTitle ) ) {
			post.setMetaTitle( trim( arguments.metaTitle ) );
		}
		if ( !isNull( arguments.metaDescription ) ) {
			post.setMetaDescription( trim( arguments.metaDescription ) );
		}
		// No default on the argument, so an update that says nothing about the
		// heading leaves it alone. A default of `true` here would turn it back
		// on every time somebody edited a post's content from anywhere else.
		if ( !isNull( arguments.showHeading ) ) {
			post.setShowHeading( arguments.showHeading );
		}

		var updated = postRepository.update( post );

		// A renamed post moves its public URL, exactly as a page does.
		if ( post.getSlug() != oldSlug ) {
			var base = reReplace( lCase( trim( settings.basePath ?: "blog" ) ), "^/+|/+$", "", "all" );

			redirects.record(
				post.getSiteId(),
				base & "/" & oldSlug,
				base & "/" & post.getSlug()
			);
		}

		if ( !isNull( arguments.categoryIds ) ) {
			syncCategories( post.getId(), post.getSiteId(), arguments.categoryIds );
		}

		return updated;
	}

	/**
	 * `published_at` is stamped on first publish only, as with pages, so a
	 * correction does not rewrite the post's date in the archive.
	 */
	blog.models.Post function publishPost( required numeric postId ){
		var post = requirePost( arguments.postId );

		post.setStatus( post.STATUS_PUBLISHED );

		if ( isNull( post.getPublishedAt() ) ) {
			post.setPublishedAt( now() );
		}

		return postRepository.update( post );
	}

	blog.models.Post function unpublishPost( required numeric postId ){
		var post = requirePost( arguments.postId );

		post.setStatus( post.STATUS_DRAFT );

		return postRepository.update( post );
	}

	function deletePost( required numeric postId ){
		requirePost( arguments.postId );
		postRepository.delete( arguments.postId );

		return this;
	}

	/* ---------------------------------------------------------------------
	 * Categories
	 * ------------------------------------------------------------------ */

	/**
	 * @throws Blog.SiteNotFound
	 * @throws Blog.InvalidCategory
	 * @throws Blog.CategorySlugExists
	 */
	blog.models.Category function createCategory(
		required numeric siteId,
		required string name,
		string slug        = "",
		string description = ""
	){
		if ( isNull( siteRepository.findById( arguments.siteId ) ) ) {
			throw( type = "Blog.SiteNotFound", message = "No site with id [#arguments.siteId#]." );
		}

		var categoryName = trim( arguments.name );

		if ( !len( categoryName ) ) {
			throw( type = "Blog.InvalidCategory", message = "A category requires a name." );
		}

		var categorySlug = len( trim( arguments.slug ) ) ? slugify( arguments.slug ) : slugify( categoryName );

		if ( !len( categorySlug ) ) {
			throw(
				type    = "Blog.InvalidCategory",
				message = "Could not derive a usable slug from [#categoryName#]."
			);
		}

		if ( categoryRepository.existsBySlug( arguments.siteId, categorySlug ) ) {
			throw(
				type    = "Blog.CategorySlugExists",
				message = "This site already has a category [#categorySlug#]."
			);
		}

		var category = wirebox
			.getInstance( "Category@blog" )
			.setSiteId( arguments.siteId )
			.setName( categoryName )
			.setSlug( categorySlug )
			.setDescription( trim( arguments.description ) );

		return categoryRepository.create( category );
	}

	function deleteCategory( required numeric categoryId ){
		var category = categoryRepository.findById( arguments.categoryId );

		if ( isNull( category ) ) {
			throw( type = "Blog.CategoryNotFound", message = "No category [#arguments.categoryId#]." );
		}

		// Filings go with it through ON DELETE CASCADE; the posts themselves stay.
		categoryRepository.delete( arguments.categoryId );

		return this;
	}

	/**
	 * Replace a post's categories with the given set.
	 *
	 * @throws Blog.CrossTenantCategory when a category belongs to another site.
	 */
	function syncCategories(
		required numeric postId,
		required numeric siteId,
		required array categoryIds
	){
		// Validate the whole set before clearing, so a bad id leaves the post's
		// existing filing intact rather than stripping it.
		for ( var categoryId in arguments.categoryIds ) {
			var category = categoryRepository.findById( val( categoryId ) );

			if ( isNull( category ) || category.getSiteId() != arguments.siteId ) {
				throw(
					type    = "Blog.CrossTenantCategory",
					message = "Category [#categoryId#] does not belong to site [#arguments.siteId#]."
				);
			}
		}

		postRepository.clearCategories( arguments.postId );

		for ( var categoryId in arguments.categoryIds ) {
			postRepository.addCategory( arguments.postId, val( categoryId ), arguments.siteId );
		}

		return this;
	}

	/* ---------------------------------------------------------------------
	 * Reads
	 * ------------------------------------------------------------------ */

	function getPostById( required numeric postId ){
		return postRepository.findById( arguments.postId );
	}

	function getPublishedPost( required numeric siteId, required string slug ){
		return withCategories( postRepository.findPublishedBySlug( arguments.siteId, slugify( arguments.slug ) ) );
	}

	function getPostBySlug( required numeric siteId, required string slug ){
		return postRepository.findBySlug( arguments.siteId, slugify( arguments.slug ) );
	}

	array function getPostsForSite(
		required numeric siteId,
		numeric limit  = 25,
		numeric offset = 0
	){
		return postRepository.findBySiteId( arguments.siteId, arguments.limit, arguments.offset );
	}

	numeric function countPostsForSite( required numeric siteId ){
		return postRepository.countBySiteId( arguments.siteId );
	}

	array function getPublishedPosts( required numeric siteId, numeric limit = 20, numeric offset = 0 ){
		return postRepository.findPublished( arguments.siteId, arguments.limit, arguments.offset );
	}

	numeric function countPublishedPosts( required numeric siteId ){
		return postRepository.countPublished( arguments.siteId );
	}

	array function getPublishedPostsInCategory(
		required numeric siteId,
		required numeric categoryId,
		numeric limit  = 20,
		numeric offset = 0
	){
		return postRepository.findPublishedInCategory(
			arguments.siteId,
			arguments.categoryId,
			arguments.limit,
			arguments.offset
		);
	}

	numeric function countPublishedPostsInCategory( required numeric siteId, required numeric categoryId ){
		return postRepository.countPublishedInCategory( arguments.siteId, arguments.categoryId );
	}

	array function getCategoriesForSite( required numeric siteId ){
		return categoryRepository.findBySiteId( arguments.siteId );
	}

	array function getCategoriesWithCounts( required numeric siteId ){
		return categoryRepository.findWithPublishedCounts( arguments.siteId );
	}

	function getCategoryBySlug( required numeric siteId, required string slug ){
		return categoryRepository.findBySlug( arguments.siteId, slugify( arguments.slug ) );
	}

	function getCategoryById( required numeric categoryId ){
		return categoryRepository.findById( arguments.categoryId );
	}

	array function getCategoryIdsForPost( required numeric postId ){
		return postRepository.findCategoryIdsForPost( arguments.postId );
	}

	/* ---------------------------------------------------------------------
	 * Helpers
	 * ------------------------------------------------------------------ */

	boolean function isValidStatus( required string status ){
		// `listFindNoCase` rather than a member call on an array literal.
		// ColdFusion 2025 parses `[ "a", "b" ].findNoCase( x )`; 2023 does not,
		// and fails to compile the whole component with an error pointing at
		// whatever follows rather than at the literal.
		return listFindNoCase( "draft,published,archived", arguments.status ) > 0;
	}

	string function slugify( required string value ){
		// Delegated: five copies of this each dropped accented
		// characters instead of transliterating them.
		return slugifier.slugify( arguments.value );
	}

	/**
	 * Attach a post's categories, for a single-post view that shows them.
	 */
	private function withCategories( post ){
		if ( isNull( arguments.post ) ) {
			return;
		}

		var ids = postRepository.findCategoryIdsForPost( arguments.post.getId() );

		return arguments.post.setCategories( categoryRepository.findByIds( ids ) );
	}

	private function requirePost( required numeric postId ){
		var post = postRepository.findById( arguments.postId );

		if ( isNull( post ) ) {
			throw( type = "Blog.PostNotFound", message = "No post with id [#arguments.postId#]." );
		}

		return post;
	}

	private function requireAuthorForSite( required numeric userId, required numeric siteId ){
		var user = userRepository.findById( arguments.userId );

		if ( isNull( user ) ) {
			throw( type = "Blog.InvalidAuthor", message = "No user with id [#arguments.userId#]." );
		}

		if ( !user.belongsToSite( arguments.siteId ) ) {
			throw(
				type    = "Blog.InvalidAuthor",
				message = "User [#arguments.userId#] does not belong to site [#arguments.siteId#]."
			);
		}

		return user;
	}

}
