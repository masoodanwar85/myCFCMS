/**
 * Persistence for will submissions and their repeating groups.
 *
 * Children always carry `site_id` and use the composite FK, so a gift cannot
 * attach to another site's submission.
 */
component singleton extends="core.models.persistence.BaseRepository" {

	variables.SUB_TABLE = "will_submission";
	variables.SUB_COLS  = [
		"id", "site_id", "user_id", "status", "current_step",
		"wm_fullname", "wm_dob", "wm_marital", "wm_address", "wm_email", "wm_phone",
		"ex_name", "ex_address", "ex_relationship", "ex_email", "ex_phone",
		"ex_can_charge_fees", "ex_act_mode",
		"guard_name", "guard_address", "guard_children", "estate_residue",
		"poa_name", "poa_address", "poa_email", "poa_phone", "poa_commence", "poa_act_mode",
		"eg_name", "eg_address", "eg_email", "eg_phone", "eg_directions", "eg_act_mode",
		"body_disposal", "body_instructions",
		"da_include_clauses", "da_instructions", "da_notes",
		"consent_accepted", "consent_accepted_at",
		"ip_address", "user_agent", "notes", "created_at", "updated_at"
	];

	will.models.WillSubmission function createSubmission( required will.models.WillSubmission submission ){
		var stamp  = now();
		var result = variables.query
			.from( variables.SUB_TABLE )
			.insert( {
				"site_id"             : arguments.submission.getSiteId(),
				"user_id"             : nullableId( arguments.submission.getUserId() ),
				"status"              : arguments.submission.getStatus(),
				"current_step"        : nullableTinyint( arguments.submission.getCurrentStep() ),
				"wm_fullname"         : arguments.submission.getWmFullname(),
				"wm_dob"              : { value : arguments.submission.getWmDob(), cfsqltype : "cf_sql_date" },
				"wm_marital"          : arguments.submission.getWmMarital(),
				"wm_address"          : arguments.submission.getWmAddress(),
				"wm_email"            : arguments.submission.getWmEmail(),
				"wm_phone"            : arguments.submission.getWmPhone() ?: "",
				"ex_name"             : arguments.submission.getExName(),
				"ex_address"          : arguments.submission.getExAddress(),
				"ex_relationship"     : arguments.submission.getExRelationship() ?: "",
				"ex_email"            : arguments.submission.getExEmail() ?: "",
				"ex_phone"            : arguments.submission.getExPhone() ?: "",
				"ex_can_charge_fees"  : arguments.submission.getExCanChargeFees() ? 1 : 0,
				"ex_act_mode"         : arguments.submission.getExActMode() ?: "",
				"guard_name"          : arguments.submission.getGuardName() ?: "",
				"guard_address"       : arguments.submission.getGuardAddress() ?: "",
				"guard_children"      : longText( arguments.submission.getGuardChildren() ?: "" ),
				"estate_residue"      : longText( arguments.submission.getEstateResidue() ),
				"poa_name"            : arguments.submission.getPoaName() ?: "",
				"poa_address"         : arguments.submission.getPoaAddress() ?: "",
				"poa_email"           : arguments.submission.getPoaEmail() ?: "",
				"poa_phone"           : arguments.submission.getPoaPhone() ?: "",
				"poa_commence"        : arguments.submission.getPoaCommence() ?: "",
				"poa_act_mode"        : arguments.submission.getPoaActMode() ?: "",
				"eg_name"             : arguments.submission.getEgName() ?: "",
				"eg_address"          : arguments.submission.getEgAddress() ?: "",
				"eg_email"            : arguments.submission.getEgEmail() ?: "",
				"eg_phone"            : arguments.submission.getEgPhone() ?: "",
				"eg_directions"       : longText( arguments.submission.getEgDirections() ?: "" ),
				"eg_act_mode"         : arguments.submission.getEgActMode() ?: "",
				"body_disposal"       : arguments.submission.getBodyDisposal() ?: "",
				"body_instructions"   : longText( arguments.submission.getBodyInstructions() ?: "" ),
				"da_include_clauses"  : arguments.submission.getDaIncludeClauses() ?: "",
				"da_instructions"     : longText( arguments.submission.getDaInstructions() ?: "" ),
				"da_notes"            : longText( arguments.submission.getDaNotes() ?: "" ),
				"consent_accepted"    : arguments.submission.getConsentAccepted() ? 1 : 0,
				"consent_accepted_at" : arguments.submission.getConsentAccepted()
					? { value : arguments.submission.getConsentAcceptedAt() ?: stamp, cfsqltype : "cf_sql_timestamp", null : false }
					: { value : "", cfsqltype : "cf_sql_timestamp", null : true },
				"ip_address"          : arguments.submission.getIpAddress() ?: "",
				"user_agent"          : left( arguments.submission.getUserAgent() ?: "", 500 ),
				"notes"               : longText( arguments.submission.getNotes() ?: "" ),
				"created_at"          : { value : stamp, cfsqltype : "cf_sql_timestamp" },
				"updated_at"          : { value : stamp, cfsqltype : "cf_sql_timestamp" }
			} );

		arguments.submission.setId( generatedKey( result, variables.SUB_TABLE ) );
		arguments.submission.setCreatedAt( stamp );
		arguments.submission.setUpdatedAt( stamp );

		return arguments.submission;
	}

	function createGift( required will.models.WillGift gift ){
		return insertChild(
			"will_gift",
			{
				"site_id"          : arguments.gift.getSiteId(),
				"submission_id"    : arguments.gift.getSubmissionId(),
				"sort_order"       : arguments.gift.getSortOrder(),
				"gift_item"        : arguments.gift.getGiftItem(),
				"gift_beneficiary" : arguments.gift.getGiftBeneficiary()
			},
			arguments.gift
		);
	}

	function createSubstituteExecutor( required will.models.WillSubstituteExecutor executor ){
		return insertChild(
			"will_substitute_executor",
			{
				"site_id"            : arguments.executor.getSiteId(),
				"submission_id"      : arguments.executor.getSubmissionId(),
				"sort_order"         : arguments.executor.getSortOrder(),
				"ex_name"            : arguments.executor.getExName(),
				"ex_address"         : arguments.executor.getExAddress() ?: "",
				"ex_relationship"    : arguments.executor.getExRelationship() ?: "",
				"ex_email"           : arguments.executor.getExEmail() ?: "",
				"ex_phone"           : arguments.executor.getExPhone() ?: "",
				"ex_can_charge_fees" : arguments.executor.getExCanChargeFees() ? 1 : 0
			},
			arguments.executor
		);
	}

	function createBackupGuardian( required will.models.WillBackupGuardian guardian ){
		return insertChild(
			"will_backup_guardian",
			{
				"site_id"        : arguments.guardian.getSiteId(),
				"submission_id"  : arguments.guardian.getSubmissionId(),
				"sort_order"     : arguments.guardian.getSortOrder(),
				"guard_name"     : arguments.guardian.getGuardName(),
				"guard_address"  : arguments.guardian.getGuardAddress() ?: "",
				"guard_children" : longText( arguments.guardian.getGuardChildren() ?: "" )
			},
			arguments.guardian
		);
	}

	function createAdditionalAttorney( required will.models.WillAdditionalAttorney attorney ){
		return insertChild(
			"will_additional_attorney",
			{
				"site_id"       : arguments.attorney.getSiteId(),
				"submission_id" : arguments.attorney.getSubmissionId(),
				"sort_order"    : arguments.attorney.getSortOrder(),
				"poa_name"      : arguments.attorney.getPoaName(),
				"poa_address"   : arguments.attorney.getPoaAddress() ?: "",
				"poa_email"     : arguments.attorney.getPoaEmail() ?: "",
				"poa_phone"     : arguments.attorney.getPoaPhone() ?: "",
				"poa_commence"  : arguments.attorney.getPoaCommence() ?: ""
			},
			arguments.attorney
		);
	}

	function createBackupEnduringGuardian( required will.models.WillBackupEnduringGuardian guardian ){
		return insertChild(
			"will_backup_enduring_guardian",
			{
				"site_id"        : arguments.guardian.getSiteId(),
				"submission_id"  : arguments.guardian.getSubmissionId(),
				"sort_order"     : arguments.guardian.getSortOrder(),
				"eg_name"        : arguments.guardian.getEgName(),
				"eg_address"     : arguments.guardian.getEgAddress() ?: "",
				"eg_email"       : arguments.guardian.getEgEmail() ?: "",
				"eg_phone"       : arguments.guardian.getEgPhone() ?: "",
				"eg_directions"  : longText( arguments.guardian.getEgDirections() ?: "" )
			},
			arguments.guardian
		);
	}

	function findSubmissionById( required numeric id ){
		var row = variables.query.from( variables.SUB_TABLE ).select( variables.SUB_COLS ).where( "id", arguments.id ).first();

		if ( row.isEmpty() ) {
			return;
		}

		return toSubmission( row );
	}

	array function findSubmissionsForSite(
		required numeric siteId,
		numeric limit  = 25,
		numeric offset = 0
	){
		return variables.query
			.from( variables.SUB_TABLE )
			.select( variables.SUB_COLS )
			.where( "site_id", arguments.siteId )
			.orderBy( "created_at", "desc" )
			.orderBy( "id", "desc" )
			.limit( arguments.limit )
			.offset( arguments.offset )
			.get()
			.map( ( row ) => toSubmission( row ) );
	}

	numeric function countSubmissionsForSite( required numeric siteId ){
		return variables.query.from( variables.SUB_TABLE ).where( "site_id", arguments.siteId ).count();
	}

	function deleteSubmission( required numeric submissionId ){
		variables.query.from( variables.SUB_TABLE ).where( "id", arguments.submissionId ).delete();
		return this;
	}

	array function findGifts( required numeric siteId, required numeric submissionId ){
		return variables.query
			.from( "will_gift" )
			.where( "site_id", arguments.siteId )
			.where( "submission_id", arguments.submissionId )
			.orderBy( "sort_order" )
			.get()
			.map( ( row ) => {
				return wirebox
					.getInstance( "WillGift@will" )
					.setId( row.id )
					.setSiteId( row.site_id )
					.setSubmissionId( row.submission_id )
					.setSortOrder( row.sort_order )
					.setGiftItem( row.gift_item )
					.setGiftBeneficiary( row.gift_beneficiary );
			} );
	}

	array function findSubstituteExecutors( required numeric siteId, required numeric submissionId ){
		return variables.query
			.from( "will_substitute_executor" )
			.where( "site_id", arguments.siteId )
			.where( "submission_id", arguments.submissionId )
			.orderBy( "sort_order" )
			.get()
			.map( ( row ) => {
				return wirebox
					.getInstance( "WillSubstituteExecutor@will" )
					.setId( row.id )
					.setSiteId( row.site_id )
					.setSubmissionId( row.submission_id )
					.setSortOrder( row.sort_order )
					.setExName( row.ex_name )
					.setExAddress( row.ex_address ?: "" )
					.setExRelationship( row.ex_relationship ?: "" )
					.setExEmail( row.ex_email ?: "" )
					.setExPhone( row.ex_phone ?: "" )
					.setExCanChargeFees( row.ex_can_charge_fees ? true : false );
			} );
	}

	array function findBackupGuardians( required numeric siteId, required numeric submissionId ){
		return variables.query
			.from( "will_backup_guardian" )
			.where( "site_id", arguments.siteId )
			.where( "submission_id", arguments.submissionId )
			.orderBy( "sort_order" )
			.get()
			.map( ( row ) => {
				return wirebox
					.getInstance( "WillBackupGuardian@will" )
					.setId( row.id )
					.setSiteId( row.site_id )
					.setSubmissionId( row.submission_id )
					.setSortOrder( row.sort_order )
					.setGuardName( row.guard_name )
					.setGuardAddress( row.guard_address ?: "" )
					.setGuardChildren( row.guard_children ?: "" );
			} );
	}

	array function findAdditionalAttorneys( required numeric siteId, required numeric submissionId ){
		return variables.query
			.from( "will_additional_attorney" )
			.where( "site_id", arguments.siteId )
			.where( "submission_id", arguments.submissionId )
			.orderBy( "sort_order" )
			.get()
			.map( ( row ) => {
				return wirebox
					.getInstance( "WillAdditionalAttorney@will" )
					.setId( row.id )
					.setSiteId( row.site_id )
					.setSubmissionId( row.submission_id )
					.setSortOrder( row.sort_order )
					.setPoaName( row.poa_name )
					.setPoaAddress( row.poa_address ?: "" )
					.setPoaEmail( row.poa_email ?: "" )
					.setPoaPhone( row.poa_phone ?: "" )
					.setPoaCommence( row.poa_commence ?: "" );
			} );
	}

	array function findBackupEnduringGuardians( required numeric siteId, required numeric submissionId ){
		return variables.query
			.from( "will_backup_enduring_guardian" )
			.where( "site_id", arguments.siteId )
			.where( "submission_id", arguments.submissionId )
			.orderBy( "sort_order" )
			.get()
			.map( ( row ) => {
				return wirebox
					.getInstance( "WillBackupEnduringGuardian@will" )
					.setId( row.id )
					.setSiteId( row.site_id )
					.setSubmissionId( row.submission_id )
					.setSortOrder( row.sort_order )
					.setEgName( row.eg_name )
					.setEgAddress( row.eg_address ?: "" )
					.setEgEmail( row.eg_email ?: "" )
					.setEgPhone( row.eg_phone ?: "" )
					.setEgDirections( row.eg_directions ?: "" );
			} );
	}

	/* ---------------------------------------------------------------- mapping */

	will.models.WillSubmission function toSubmission( required struct row ){
		return wirebox
			.getInstance( "WillSubmission@will" )
			.setId( arguments.row.id )
			.setSiteId( arguments.row.site_id )
			.setUserId( arguments.row.user_id ?: javacast( "null", "" ) )
			.setStatus( arguments.row.status )
			.setCurrentStep( arguments.row.current_step ?: javacast( "null", "" ) )
			.setWmFullname( arguments.row.wm_fullname )
			.setWmDob( arguments.row.wm_dob )
			.setWmMarital( arguments.row.wm_marital )
			.setWmAddress( arguments.row.wm_address )
			.setWmEmail( arguments.row.wm_email )
			.setWmPhone( arguments.row.wm_phone ?: "" )
			.setExName( arguments.row.ex_name )
			.setExAddress( arguments.row.ex_address )
			.setExRelationship( arguments.row.ex_relationship ?: "" )
			.setExEmail( arguments.row.ex_email ?: "" )
			.setExPhone( arguments.row.ex_phone ?: "" )
			.setExCanChargeFees( arguments.row.ex_can_charge_fees ? true : false )
			.setExActMode( arguments.row.ex_act_mode ?: "" )
			.setGuardName( arguments.row.guard_name ?: "" )
			.setGuardAddress( arguments.row.guard_address ?: "" )
			.setGuardChildren( arguments.row.guard_children ?: "" )
			.setEstateResidue( arguments.row.estate_residue )
			.setPoaName( arguments.row.poa_name ?: "" )
			.setPoaAddress( arguments.row.poa_address ?: "" )
			.setPoaEmail( arguments.row.poa_email ?: "" )
			.setPoaPhone( arguments.row.poa_phone ?: "" )
			.setPoaCommence( arguments.row.poa_commence ?: "" )
			.setPoaActMode( arguments.row.poa_act_mode ?: "" )
			.setEgName( arguments.row.eg_name ?: "" )
			.setEgAddress( arguments.row.eg_address ?: "" )
			.setEgEmail( arguments.row.eg_email ?: "" )
			.setEgPhone( arguments.row.eg_phone ?: "" )
			.setEgDirections( arguments.row.eg_directions ?: "" )
			.setEgActMode( arguments.row.eg_act_mode ?: "" )
			.setBodyDisposal( arguments.row.body_disposal ?: "" )
			.setBodyInstructions( arguments.row.body_instructions ?: "" )
			.setDaIncludeClauses( arguments.row.da_include_clauses ?: "" )
			.setDaInstructions( arguments.row.da_instructions ?: "" )
			.setDaNotes( arguments.row.da_notes ?: "" )
			.setConsentAccepted( arguments.row.consent_accepted ? true : false )
			.setConsentAcceptedAt( arguments.row.consent_accepted_at ?: javacast( "null", "" ) )
			.setIpAddress( arguments.row.ip_address ?: "" )
			.setUserAgent( arguments.row.user_agent ?: "" )
			.setNotes( arguments.row.notes ?: "" )
			.setCreatedAt( arguments.row.created_at )
			.setUpdatedAt( arguments.row.updated_at );
	}

	private function insertChild( required string table, required struct data, required any entity ){
		var stamp = now();

		arguments.data[ "created_at" ] = { value : stamp, cfsqltype : "cf_sql_timestamp" };

		var result = variables.query.from( arguments.table ).insert( arguments.data );

		arguments.entity.setId( generatedKey( result, arguments.table ) );
		arguments.entity.setCreatedAt( stamp );

		return arguments.entity;
	}

	private function longText( required string value ){
		return { value : arguments.value, cfsqltype : "cf_sql_longvarchar" };
	}

	private struct function nullableId( value ){
		return {
			value     : isNull( arguments.value ) ? "" : arguments.value,
			cfsqltype : "cf_sql_bigint",
			null      : isNull( arguments.value )
		};
	}

	private struct function nullableTinyint( value ){
		return {
			value     : isNull( arguments.value ) ? "" : arguments.value,
			cfsqltype : "cf_sql_tinyint",
			null      : isNull( arguments.value )
		};
	}

}
