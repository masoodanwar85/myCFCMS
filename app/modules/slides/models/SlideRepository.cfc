/**
 * Persistence for hero slides, scoped per site.
 */
component singleton extends="core.models.persistence.BaseRepository" {

	variables.TABLE   = "slides";
	variables.COLUMNS = [
		"id",
		"site_id",
		"image_url",
		"image_alt",
		"overlay_html",
		"h_align",
		"v_align",
		"sort_order",
		"is_published",
		"created_at",
		"updated_at"
	];

	slides.models.Slide function create( required slides.models.Slide slide ){
		var stamp  = now();
		var result = variables.query
			.from( variables.TABLE )
			.insert( {
				"site_id"      : arguments.slide.getSiteId(),
				"image_url"    : arguments.slide.getImageUrl() ?: "",
				"image_alt"    : arguments.slide.getImageAlt() ?: "",
				"overlay_html" : { value : arguments.slide.getOverlayHtml() ?: "", cfsqltype : "cf_sql_longvarchar" },
				"h_align"      : arguments.slide.getHAlign(),
				"v_align"      : arguments.slide.getVAlign(),
				"sort_order"   : val( arguments.slide.getSortOrder() ),
				"is_published" : {
					value     : arguments.slide.getIsPublished() ? 1 : 0,
					cfsqltype : "cf_sql_tinyint",
					null      : false
				},
				"created_at"   : { value : stamp, cfsqltype : "cf_sql_timestamp" },
				"updated_at"   : { value : stamp, cfsqltype : "cf_sql_timestamp" }
			} );

		arguments.slide.setId( generatedKey( result, variables.TABLE ) );
		arguments.slide.setCreatedAt( stamp );
		arguments.slide.setUpdatedAt( stamp );

		return arguments.slide;
	}

	slides.models.Slide function update( required slides.models.Slide slide ){
		var stamp = now();

		variables.query
			.from( variables.TABLE )
			.where( "id", arguments.slide.getId() )
			.update( {
				"image_url"    : arguments.slide.getImageUrl() ?: "",
				"image_alt"    : arguments.slide.getImageAlt() ?: "",
				"overlay_html" : { value : arguments.slide.getOverlayHtml() ?: "", cfsqltype : "cf_sql_longvarchar" },
				"h_align"      : arguments.slide.getHAlign(),
				"v_align"      : arguments.slide.getVAlign(),
				"sort_order"   : val( arguments.slide.getSortOrder() ),
				"is_published" : {
					value     : arguments.slide.getIsPublished() ? 1 : 0,
					cfsqltype : "cf_sql_tinyint",
					null      : false
				},
				"updated_at"   : { value : stamp, cfsqltype : "cf_sql_timestamp" }
			} );

		arguments.slide.setUpdatedAt( stamp );

		return arguments.slide;
	}

	function findById( required numeric id ){
		return toSlideOrNull( baseQuery().where( "id", arguments.id ).first() );
	}

	array function findBySiteId( required numeric siteId ){
		return baseQuery()
			.where( "site_id", arguments.siteId )
			.orderBy( "sort_order" )
			.orderBy( "id" )
			.get()
			.map( ( row ) => toSlide( row ) );
	}

	array function findPublished( required numeric siteId ){
		return baseQuery()
			.where( "site_id", arguments.siteId )
			.where( "is_published", 1 )
			.orderBy( "sort_order" )
			.orderBy( "id" )
			.get()
			.map( ( row ) => toSlide( row ) );
	}

	numeric function nextSortOrder( required numeric siteId ){
		var row = variables.query
			.from( variables.TABLE )
			.select( [ "sort_order" ] )
			.where( "site_id", arguments.siteId )
			.orderBy( "sort_order", "desc" )
			.orderBy( "id", "desc" )
			.limit( 1 )
			.first();

		if ( row.isEmpty() ) {
			return 10;
		}

		return val( row.sort_order ) + 10;
	}

	function delete( required numeric id ){
		variables.query.from( variables.TABLE ).where( "id", arguments.id ).delete();
		return this;
	}

	slides.models.Slide function toSlide( required struct row ){
		return wirebox
			.getInstance( "Slide@slides" )
			.setId( arguments.row.id )
			.setSiteId( arguments.row.site_id )
			.setImageUrl( arguments.row.image_url ?: "" )
			.setImageAlt( arguments.row.image_alt ?: "" )
			.setOverlayHtml( arguments.row.overlay_html ?: "" )
			.setHAlign( arguments.row.h_align ?: "left" )
			.setVAlign( arguments.row.v_align ?: "middle" )
			.setSortOrder( val( arguments.row.sort_order ) )
			.setIsPublished( val( arguments.row.is_published ) ? true : false )
			.setCreatedAt( arguments.row.created_at )
			.setUpdatedAt( arguments.row.updated_at );
	}

	private function baseQuery(){
		return variables.query.from( variables.TABLE ).select( variables.COLUMNS );
	}

	private function toSlideOrNull( required struct row ){
		if ( arguments.row.isEmpty() ) {
			return;
		}
		return toSlide( arguments.row );
	}

}
