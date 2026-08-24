/**
 * The Blog module's own admin screens, at /admin/blog.
 *
 * Extends Core's SecuredHandler, so the module depends on Core alone and never
 * on the admin module whose shell it appears inside.
 */
component extends="core.models.security.SecuredHandler" {

	property name="blogService" inject="BlogService@blog";
	property name="paginator"   inject="Paginator@core";

	variables.permissions = {
		"index"          : "blog.view",
		"new"            : "blog.create",
		"create"         : "blog.create",
		"edit"           : "blog.update",
		"update"         : "blog.update",
		"publish"        : "blog.publish",
		"unpublish"      : "blog.publish",
		"remove"         : "blog.delete",
		"categories"     : "blog.view",
		"createCategory" : "blog.categories.manage",
		"removeCategory" : "blog.categories.manage",
		"$every"         : "blog.view"
	};

	function index( event, rc, prc ){
		var siteId = prc.currentSite.getId();

		prc.pageTitle = "Blog";

		// The admin used to fetch every post a site had ever written to render
		// one screen.
		prc.pagination = paginator.paginate(
			total   = blogService.countPostsForSite( siteId ),
			page    = paginator.readPage( rc.page ?: 1 ),
			perPage = 25
		);
		prc.pageBase   = "/admin/blog";
		prc.posts      = blogService.getPostsForSite( siteId, prc.pagination.perPage, prc.pagination.offset );
		prc.categories = blogService.getCategoriesWithCounts( siteId );

		prc.canCreate  = authorization.can( prc.currentUser, "blog.create" );
		prc.canUpdate  = authorization.can( prc.currentUser, "blog.update" );
		prc.canPublish = authorization.can( prc.currentUser, "blog.publish" );
		prc.canDelete  = authorization.can( prc.currentUser, "blog.delete" );
		prc.canManageCategories = authorization.can( prc.currentUser, "blog.categories.manage" );

		event.setView( view = "admin/index", module = "blog" );
	}

	function new( event, rc, prc ){
		prc.pageTitle  = "New post";
		prc.post       = "";
		prc.categories = blogService.getCategoriesForSite( prc.currentSite.getId() );
		prc.selected   = [];

		prc.useEditor = true;

		event.setView( view = "admin/form", module = "blog" );
	}

	function create( event, rc, prc ){
		try {
			blogService.createPost(
				siteId          = prc.currentSite.getId(),
				title           = rc.title ?: "",
				slug            = rc.slug ?: "",
				excerpt         = rc.excerpt ?: "",
				content         = rc.content ?: "",
				metaTitle       = rc.metaTitle ?: "",
				metaDescription = rc.metaDescription ?: "",
				categoryIds     = listToArray( rc.categoryIds ?: "" ),
				authorId        = prc.currentUser.getId(),
				allowUnfilteredHtml = mayPostRawHtml( prc )
			);
		} catch ( any e ) {
			return done( "/admin/blog/new", e.message, "error" );
		}

		return done( "/admin/blog", "Post created." );
	}

	function edit( event, rc, prc ){
		var post = requireSitePost( rc.id ?: 0, prc );

		prc.pageTitle  = "Edit post";
		prc.post       = post;
		prc.categories = blogService.getCategoriesForSite( prc.currentSite.getId() );
		prc.selected   = blogService.getCategoryIdsForPost( post.getId() );

		prc.useEditor = true;

		event.setView( view = "admin/form", module = "blog" );
	}

	function update( event, rc, prc ){
		var post = requireSitePost( rc.id ?: 0, prc );

		try {
			blogService.updatePost(
				postId          = post.getId(),
				title           = rc.title ?: post.getTitle(),
				slug            = rc.slug ?: post.getSlug(),
				excerpt         = rc.excerpt ?: "",
				content         = rc.content ?: "",
				metaTitle       = rc.metaTitle ?: "",
				metaDescription = rc.metaDescription ?: "",
				categoryIds     = listToArray( rc.categoryIds ?: "" ),
				allowUnfilteredHtml = mayPostRawHtml( prc )
			);
		} catch ( any e ) {
			return done( "/admin/blog/edit/" & post.getId(), e.message, "error" );
		}

		return done( "/admin/blog", "Post saved." );
	}

	function publish( event, rc, prc ){
		blogService.publishPost( requireSitePost( rc.id ?: 0, prc ).getId() );

		return done( "/admin/blog", "Post published." );
	}

	function unpublish( event, rc, prc ){
		blogService.unpublishPost( requireSitePost( rc.id ?: 0, prc ).getId() );

		return done( "/admin/blog", "Post unpublished." );
	}

	function remove( event, rc, prc ){
		blogService.deletePost( requireSitePost( rc.id ?: 0, prc ).getId() );

		return done( "/admin/blog", "Post deleted." );
	}

	function createCategory( event, rc, prc ){
		try {
			blogService.createCategory(
				siteId      = prc.currentSite.getId(),
				name        = rc.name ?: "",
				slug        = rc.slug ?: "",
				description = rc.description ?: ""
			);
		} catch ( any e ) {
			return done( "/admin/blog", e.message, "error" );
		}

		return done( "/admin/blog", "Category created." );
	}

	function removeCategory( event, rc, prc ){
		var category = blogService.getCategoryById( val( rc.id ?: 0 ) );

		if ( isNull( category ) || category.getSiteId() != prc.currentSite.getId() ) {
			return done( "/admin/blog", "No such category on this site.", "error" );
		}

		blogService.deleteCategory( category.getId() );

		return done( "/admin/blog", "Category deleted." );
	}

	private boolean function mayPostRawHtml( required struct prc ){
		return authorization.can( arguments.prc.currentUser, "content.unfiltered" );
	}

	/**
	 * Load a post, refusing anything that is not this site's.
	 */
	private function requireSitePost( required numeric postId, required struct prc ){
		var post = blogService.getPostById( arguments.postId );

		if ( isNull( post ) || post.getSiteId() != arguments.prc.currentSite.getId() ) {
			throw( type = "Admin.NotFoundHere", message = "No post [#arguments.postId#] on this site." );
		}

		return post;
	}

}
