/**
 * Persistence for FAQs, scoped per site.
 */
component singleton extends="core.models.persistence.BaseRepository" {

	variables.TABLE   = "faqs";
	variables.COLUMNS = [
		"id",
		"site_id",
		"question",
		"answer",
		"sort_order",
		"is_published",
		"created_at",
		"updated_at"
	];

	faqs.models.Faq function create( required faqs.models.Faq faq ){
		var stamp  = now();
		var result = variables.query
			.from( variables.TABLE )
			.insert( {
				"site_id"      : arguments.faq.getSiteId(),
				"question"     : arguments.faq.getQuestion(),
				"answer"       : { value : arguments.faq.getAnswer() ?: "", cfsqltype : "cf_sql_longvarchar" },
				"sort_order"   : val( arguments.faq.getSortOrder() ),
				"is_published" : {
					value     : arguments.faq.getIsPublished() ? 1 : 0,
					cfsqltype : "cf_sql_tinyint",
					null      : false
				},
				"created_at"   : { value : stamp, cfsqltype : "cf_sql_timestamp" },
				"updated_at"   : { value : stamp, cfsqltype : "cf_sql_timestamp" }
			} );

		arguments.faq.setId( generatedKey( result, variables.TABLE ) );
		arguments.faq.setCreatedAt( stamp );
		arguments.faq.setUpdatedAt( stamp );

		return arguments.faq;
	}

	faqs.models.Faq function update( required faqs.models.Faq faq ){
		var stamp = now();

		variables.query
			.from( variables.TABLE )
			.where( "id", arguments.faq.getId() )
			.update( {
				"question"     : arguments.faq.getQuestion(),
				"answer"       : { value : arguments.faq.getAnswer() ?: "", cfsqltype : "cf_sql_longvarchar" },
				"sort_order"   : val( arguments.faq.getSortOrder() ),
				"is_published" : {
					value     : arguments.faq.getIsPublished() ? 1 : 0,
					cfsqltype : "cf_sql_tinyint",
					null      : false
				},
				"updated_at"   : { value : stamp, cfsqltype : "cf_sql_timestamp" }
			} );

		arguments.faq.setUpdatedAt( stamp );

		return arguments.faq;
	}

	function findById( required numeric id ){
		return toFaqOrNull( baseQuery().where( "id", arguments.id ).first() );
	}

	array function findBySiteId( required numeric siteId ){
		return baseQuery()
			.where( "site_id", arguments.siteId )
			.orderBy( "sort_order" )
			.orderBy( "id" )
			.get()
			.map( ( row ) => toFaq( row ) );
	}

	numeric function countBySiteId( required numeric siteId ){
		return variables.query.from( variables.TABLE ).where( "site_id", arguments.siteId ).count();
	}

	array function findPublished( required numeric siteId ){
		return baseQuery()
			.where( "site_id", arguments.siteId )
			.where( "is_published", 1 )
			.orderBy( "sort_order" )
			.orderBy( "id" )
			.get()
			.map( ( row ) => toFaq( row ) );
	}

	numeric function countPublished( required numeric siteId ){
		return variables.query
			.from( variables.TABLE )
			.where( "site_id", arguments.siteId )
			.where( "is_published", 1 )
			.count();
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

	faqs.models.Faq function toFaq( required struct row ){
		return wirebox
			.getInstance( "Faq@faqs" )
			.setId( arguments.row.id )
			.setSiteId( arguments.row.site_id )
			.setQuestion( arguments.row.question )
			.setAnswer( arguments.row.answer ?: "" )
			.setSortOrder( val( arguments.row.sort_order ) )
			.setIsPublished( val( arguments.row.is_published ) ? true : false )
			.setCreatedAt( arguments.row.created_at )
			.setUpdatedAt( arguments.row.updated_at );
	}

	private function baseQuery(){
		return variables.query.from( variables.TABLE ).select( variables.COLUMNS );
	}

	private function toFaqOrNull( required struct row ){
		if ( arguments.row.isEmpty() ) {
			return;
		}
		return toFaq( arguments.row );
	}

}
