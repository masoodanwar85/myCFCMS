/**
 * The blog archive and its published posts, as sitemap entries.
 *
 * Categories are deliberately absent. A category page is a filtered view of
 * posts that are already listed individually, so including it asks a crawler to
 * spend its budget on near-duplicate content — and on a site with many
 * categories it can be most of the sitemap.
 */
component singleton accessors="true" {

	property name="postRepository" inject="PostRepository@blog";
	property name="settings"       inject="coldbox:moduleSettings:blog";

	array function getSitemapEntries( required numeric siteId ){
		var base = reReplace( lCase( trim( settings.basePath ?: "blog" ) ), "^/+|/+$", "", "all" );

		// Nothing published means no archive worth listing: the URL renders,
		// but an empty index is not something to invite a crawler to.
		var published = postRepository.findPublished( arguments.siteId, 50000, 0 );

		if ( !published.len() ) {
			return [];
		}

		var entries = [
			{
				"path"            : base,
				"lastModified"    : published[ 1 ].getPublishedAt(),
				"changeFrequency" : "weekly",
				"priority"        : 0.8
			}
		];

		for ( var post in published ) {
			entries.append( {
				"path"            : base & "/" & post.getSlug(),
				"lastModified"    : post.getUpdatedAt(),
				// A published post is rarely edited again.
				"changeFrequency" : "yearly",
				"priority"        : 0.6
			} );
		}

		return entries;
	}

}
