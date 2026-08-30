/**
 * Will questionnaire use cases.
 *
 * `submit()` is reachable by anyone on the internet, same as Contact: validate
 * and length-cap, store as text, never as markup. Repeating groups are inserted
 * in the same transaction as the parent row so a half-written will cannot land.
 *
 * Mapping of repeating form fields (gifts, extra attorneys, …) is filled in
 * once the wizard HTML is in the theme — see parseRepeatingGroups().
 */
component singleton accessors="true" {

	property name="willRepository"   inject="WillRepository@will";
	property name="authentication"   inject="AuthenticationService@core";
	property name="wirebox"          inject="wirebox";
	property name="log"              inject="logbox:logger:{this}";

	variables.STATUS_SUBMITTED = "submitted";

	/* -------------------------------------------------------------- public */

	/**
	 * @return An array of human-readable messages. Empty means acceptable.
	 */
	array function validateSubmission( required struct values ){
		var errors = [];

		if ( !len( trim( arguments.values.wm_fullname ?: "" ) ) ) {
			errors.append( "Please give your full name." );
		} else if ( len( trim( arguments.values.wm_fullname ) ) > 255 ) {
			errors.append( "That name is too long." );
		}

		if ( isNull( parseDob( arguments.values.wm_dob ?: "" ) ) ) {
			errors.append( "Please give a usable date of birth." );
		}

		if ( !len( trim( arguments.values.wm_marital ?: "" ) ) ) {
			errors.append( "Please say your marital status." );
		}

		if ( !len( trim( arguments.values.wm_address ?: "" ) ) ) {
			errors.append( "Please give your address." );
		} else if ( len( trim( arguments.values.wm_address ) ) > 500 ) {
			errors.append( "That address is too long." );
		}

		if ( !len( trim( arguments.values.wm_email ?: "" ) ) ) {
			errors.append( "Please give an email address." );
		} else if ( !isValidEmail( trim( arguments.values.wm_email ) ) || len( trim( arguments.values.wm_email ) ) > 255 ) {
			errors.append( "That email address does not look right." );
		}

		if ( !len( trim( arguments.values.ex_name ?: "" ) ) ) {
			errors.append( "Please name an executor." );
		}

		if ( !len( trim( arguments.values.ex_address ?: "" ) ) ) {
			errors.append( "Please give the executor's address." );
		}

		if ( !len( trim( arguments.values.estate_residue ?: "" ) ) ) {
			errors.append( "Please say who should receive the residue of the estate." );
		}

		return errors;
	}

	/**
	 * Store a completed wizard POST: the main row, then every repeating group.
	 *
	 * @throws Will.InvalidSubmission
	 */
	will.models.WillSubmission function submit(
		required numeric siteId,
		required struct values,
		string ipAddress = "",
		string userAgent = ""
	){
		var errors = validateSubmission( arguments.values );

		if ( errors.len() ) {
			throw(
				type    = "Will.InvalidSubmission",
				message = errors[ 1 ],
				detail  = errors.toList( " " )
			);
		}

		var stored = "";

		transaction {
			stored = willRepository.createSubmission( toSubmission( argumentCollection = arguments ) );
			insertRepeatingGroups( stored, parseRepeatingGroups( arguments.values ) );
		}

		return stored;
	}

	function getSubmissionById( required numeric submissionId ){
		return willRepository.findSubmissionById( arguments.submissionId );
	}

	array function getSubmissions( required numeric siteId, numeric limit = 25, numeric offset = 0 ){
		return willRepository.findSubmissionsForSite( arguments.siteId, arguments.limit, arguments.offset );
	}

	numeric function countSubmissions( required numeric siteId ){
		return willRepository.countSubmissionsForSite( arguments.siteId );
	}

	function deleteSubmission( required numeric submissionId ){
		willRepository.deleteSubmission( arguments.submissionId );
		return this;
	}

	struct function getRelated( required will.models.WillSubmission submission ){
		var siteId = arguments.submission.getSiteId();
		var subId  = arguments.submission.getId();

		return {
			"gifts"                   : willRepository.findGifts( siteId, subId ),
			"substituteExecutors"     : willRepository.findSubstituteExecutors( siteId, subId ),
			"backupGuardians"         : willRepository.findBackupGuardians( siteId, subId ),
			"additionalAttorneys"     : willRepository.findAdditionalAttorneys( siteId, subId ),
			"backupEnduringGuardians" : willRepository.findBackupEnduringGuardians( siteId, subId )
		};
	}

	boolean function isValidEmail( required string email ){
		return reFind( "^[^@\s]+@[^@\s.]+(\.[^@\s.]+)+$", arguments.email ) > 0;
	}

	/* ---------------------------------------------------------------- parse */

	/**
	 * Repeating groups from the wizard's hidden JSON fields.
	 *
	 * The theme script writes `gifts_json`, `substitute_executors_json`,
	 * `backup_guardians_json`, `additional_attorneys_json` and
	 * `backup_enduring_guardians_json` on submit. Empty cards are dropped.
	 */
	struct function parseRepeatingGroups( required struct values ){
		var gifts = [];

		for ( var gift in jsonArray( arguments.values.gifts_json ?: "" ) ) {
			if ( !isStruct( gift ) ) {
				continue;
			}
			var item        = trim( gift.item ?: ( gift.giftItem ?: "" ) );
			var beneficiary = trim( gift.beneficiary ?: ( gift.giftBeneficiary ?: "" ) );

			if ( !len( item ) || !len( beneficiary ) ) {
				continue;
			}

			gifts.append( { "giftItem" : item, "giftBeneficiary" : beneficiary } );
		}

		var executors = [];

		for ( var executor in jsonArray( arguments.values.substitute_executors_json ?: "" ) ) {
			if ( !isStruct( executor ) ) {
				continue;
			}
			var exName = trim( executor.ex_name ?: ( executor.exName ?: "" ) );

			if ( !len( exName ) ) {
				continue;
			}

			executors.append( {
				"exName"          : exName,
				"exAddress"       : trim( executor.ex_address ?: ( executor.exAddress ?: "" ) ),
				"exRelationship"  : trim( executor.ex_relationship ?: ( executor.exRelationship ?: "" ) ),
				"exEmail"         : trim( executor.ex_email ?: ( executor.exEmail ?: "" ) ),
				"exPhone"         : trim( executor.ex_phone ?: ( executor.exPhone ?: "" ) ),
				"exCanChargeFees" : executor.ex_can_charge_fees ?: ( executor.exCanChargeFees ?: "" )
			} );
		}

		var guardians = [];

		for ( var guardian in jsonArray( arguments.values.backup_guardians_json ?: "" ) ) {
			if ( !isStruct( guardian ) ) {
				continue;
			}
			var guardName = trim( guardian.guard_name ?: ( guardian.guardName ?: "" ) );

			if ( !len( guardName ) ) {
				continue;
			}

			guardians.append( {
				"guardName"     : guardName,
				"guardAddress"  : trim( guardian.guard_address ?: ( guardian.guardAddress ?: "" ) ),
				"guardChildren" : trim( guardian.guard_children ?: ( guardian.guardChildren ?: "" ) )
			} );
		}

		var attorneys = [];

		for ( var attorney in jsonArray( arguments.values.additional_attorneys_json ?: "" ) ) {
			if ( !isStruct( attorney ) ) {
				continue;
			}
			var poaName = trim( attorney.poa_name ?: ( attorney.poaName ?: "" ) );

			if ( !len( poaName ) ) {
				continue;
			}

			attorneys.append( {
				"poaName"      : poaName,
				"poaAddress"   : trim( attorney.poa_address ?: ( attorney.poaAddress ?: "" ) ),
				"poaEmail"     : trim( attorney.poa_email ?: ( attorney.poaEmail ?: "" ) ),
				"poaPhone"     : trim( attorney.poa_phone ?: ( attorney.poaPhone ?: "" ) ),
				"poaCommence"  : trim( attorney.poa_commence ?: ( attorney.poaCommence ?: "" ) )
			} );
		}

		var enduring = [];

		for ( var eg in jsonArray( arguments.values.backup_enduring_guardians_json ?: "" ) ) {
			if ( !isStruct( eg ) ) {
				continue;
			}
			var egName = trim( eg.eg_name ?: ( eg.egName ?: "" ) );

			if ( !len( egName ) ) {
				continue;
			}

			enduring.append( {
				"egName"        : egName,
				"egAddress"     : trim( eg.eg_address ?: ( eg.egAddress ?: "" ) ),
				"egEmail"       : trim( eg.eg_email ?: ( eg.egEmail ?: "" ) ),
				"egPhone"       : trim( eg.eg_phone ?: ( eg.egPhone ?: "" ) ),
				"egDirections"  : trim( eg.eg_directions ?: ( eg.egDirections ?: "" ) )
			} );
		}

		return {
			"gifts"                   : gifts,
			"substituteExecutors"     : executors,
			"backupGuardians"         : guardians,
			"additionalAttorneys"     : attorneys,
			"backupEnduringGuardians" : enduring
		};
	}

	private array function jsonArray( required string raw ){
		var payload = trim( arguments.raw );

		if ( !len( payload ) || !isJSON( payload ) ) {
			return [];
		}

		var data = deserializeJSON( payload );

		return isArray( data ) ? data : [];
	}

	/* --------------------------------------------------------------- helpers */

	private will.models.WillSubmission function toSubmission(
		required numeric siteId,
		required struct values,
		string ipAddress = "",
		string userAgent = ""
	){
		var v      = arguments.values;
		var signed = authentication.getCurrentUser();
		var row    = wirebox
			.getInstance( "WillSubmission@will" )
			.setSiteId( arguments.siteId )
			.setStatus( variables.STATUS_SUBMITTED )
			.setWmFullname( clipped( v.wm_fullname ?: "", 255 ) )
			.setWmDob( parseDob( v.wm_dob ?: "" ) )
			.setWmMarital( clipped( v.wm_marital ?: "", 50 ) )
			.setWmAddress( clipped( v.wm_address ?: "", 500 ) )
			.setWmEmail( lCase( clipped( v.wm_email ?: "", 255 ) ) )
			.setWmPhone( clipped( v.wm_phone ?: "", 50 ) )
			.setExName( clipped( v.ex_name ?: "", 255 ) )
			.setExAddress( clipped( v.ex_address ?: "", 500 ) )
			.setExRelationship( clipped( v.ex_relationship ?: "", 255 ) )
			.setExEmail( clipped( v.ex_email ?: "", 255 ) )
			.setExPhone( clipped( v.ex_phone ?: "", 50 ) )
			.setExCanChargeFees( isChecked( v.ex_can_charge_fees ?: "" ) )
			.setExActMode( clipped( v.ex_act_mode ?: "", 50 ) )
			.setGuardName( clipped( v.guard_name ?: "", 255 ) )
			.setGuardAddress( clipped( v.guard_address ?: "", 500 ) )
			.setGuardChildren( trim( v.guard_children ?: "" ) )
			.setEstateResidue( trim( v.estate_residue ?: "" ) )
			.setPoaName( clipped( v.poa_name ?: "", 255 ) )
			.setPoaAddress( clipped( v.poa_address ?: "", 500 ) )
			.setPoaEmail( clipped( v.poa_email ?: "", 255 ) )
			.setPoaPhone( clipped( v.poa_phone ?: "", 50 ) )
			.setPoaCommence( clipped( v.poa_commence ?: "", 255 ) )
			.setPoaActMode( clipped( v.poa_act_mode ?: "", 50 ) )
			.setEgName( clipped( v.eg_name ?: "", 255 ) )
			.setEgAddress( clipped( v.eg_address ?: "", 500 ) )
			.setEgEmail( clipped( v.eg_email ?: "", 255 ) )
			.setEgPhone( clipped( v.eg_phone ?: "", 50 ) )
			.setEgDirections( trim( v.eg_directions ?: "" ) )
			.setEgActMode( clipped( v.eg_act_mode ?: "", 50 ) )
			.setBodyDisposal( clipped( v.body_disposal ?: "", 50 ) )
			.setBodyInstructions( trim( v.body_instructions ?: "" ) )
			.setDaIncludeClauses( clipped( v.da_include_clauses ?: "", 10 ) )
			.setDaInstructions( trim( v.da_instructions ?: "" ) )
			.setDaNotes( trim( v.da_notes ?: "" ) )
			.setConsentAccepted( isChecked( v.consent_accepted ?: "" ) )
			.setIpAddress( left( arguments.ipAddress, 45 ) )
			.setUserAgent( arguments.userAgent );

		if ( val( v.current_step ?: "" ) ) {
			row.setCurrentStep( val( v.current_step ) );
		}

		if ( row.getConsentAccepted() ) {
			row.setConsentAcceptedAt( now() );
		}

		if ( !isNull( signed ) ) {
			row.setUserId( signed.getId() );
		}

		return row;
	}

	private function insertRepeatingGroups( required will.models.WillSubmission submission, required struct groups ){
		var siteId = arguments.submission.getSiteId();
		var subId  = arguments.submission.getId();
		var order  = 0;

		order = 0;
		for ( var gift in arguments.groups.gifts ) {
			order++;
			willRepository.createGift(
				wirebox
					.getInstance( "WillGift@will" )
					.setSiteId( siteId )
					.setSubmissionId( subId )
					.setSortOrder( order )
					.setGiftItem( clipped( gift.giftItem ?: "", 500 ) )
					.setGiftBeneficiary( clipped( gift.giftBeneficiary ?: "", 500 ) )
			);
		}

		order = 0;
		for ( var executor in arguments.groups.substituteExecutors ) {
			order++;
			willRepository.createSubstituteExecutor(
				wirebox
					.getInstance( "WillSubstituteExecutor@will" )
					.setSiteId( siteId )
					.setSubmissionId( subId )
					.setSortOrder( order )
					.setExName( clipped( executor.exName ?: "", 255 ) )
					.setExAddress( clipped( executor.exAddress ?: "", 500 ) )
					.setExRelationship( clipped( executor.exRelationship ?: "", 255 ) )
					.setExEmail( clipped( executor.exEmail ?: "", 255 ) )
					.setExPhone( clipped( executor.exPhone ?: "", 50 ) )
					.setExCanChargeFees( isChecked( executor.exCanChargeFees ?: "" ) )
			);
		}

		order = 0;
		for ( var guardian in arguments.groups.backupGuardians ) {
			order++;
			willRepository.createBackupGuardian(
				wirebox
					.getInstance( "WillBackupGuardian@will" )
					.setSiteId( siteId )
					.setSubmissionId( subId )
					.setSortOrder( order )
					.setGuardName( clipped( guardian.guardName ?: "", 255 ) )
					.setGuardAddress( clipped( guardian.guardAddress ?: "", 500 ) )
					.setGuardChildren( trim( guardian.guardChildren ?: "" ) )
			);
		}

		order = 0;
		for ( var attorney in arguments.groups.additionalAttorneys ) {
			order++;
			willRepository.createAdditionalAttorney(
				wirebox
					.getInstance( "WillAdditionalAttorney@will" )
					.setSiteId( siteId )
					.setSubmissionId( subId )
					.setSortOrder( order )
					.setPoaName( clipped( attorney.poaName ?: "", 255 ) )
					.setPoaAddress( clipped( attorney.poaAddress ?: "", 500 ) )
					.setPoaEmail( clipped( attorney.poaEmail ?: "", 255 ) )
					.setPoaPhone( clipped( attorney.poaPhone ?: "", 50 ) )
					.setPoaCommence( clipped( attorney.poaCommence ?: "", 255 ) )
			);
		}

		order = 0;
		for ( var eg in arguments.groups.backupEnduringGuardians ) {
			order++;
			willRepository.createBackupEnduringGuardian(
				wirebox
					.getInstance( "WillBackupEnduringGuardian@will" )
					.setSiteId( siteId )
					.setSubmissionId( subId )
					.setSortOrder( order )
					.setEgName( clipped( eg.egName ?: "", 255 ) )
					.setEgAddress( clipped( eg.egAddress ?: "", 500 ) )
					.setEgEmail( clipped( eg.egEmail ?: "", 255 ) )
					.setEgPhone( clipped( eg.egPhone ?: "", 50 ) )
					.setEgDirections( trim( eg.egDirections ?: "" ) )
			);
		}

		return this;
	}

	/**
	 * Accepts `YYYY-MM-DD` or `DD/MM/YYYY`. Returns null when unusable.
	 */
	private function parseDob( required string raw ){
		var value = trim( arguments.raw );

		if ( !len( value ) ) {
			return;
		}

		if ( reFind( "^\d{4}-\d{2}-\d{2}$", value ) ) {
			try {
				return parseDateTime( value );
			} catch ( any e ) {
				return;
			}
		}

		if ( reFind( "^\d{1,2}/\d{1,2}/\d{4}$", value ) ) {
			var parts = listToArray( value, "/" );
			try {
				return createDate( val( parts[ 3 ] ), val( parts[ 2 ] ), val( parts[ 1 ] ) );
			} catch ( any e ) {
				return;
			}
		}

		return;
	}

	private boolean function isChecked( required any value ){
		return listFindNoCase( "1,true,yes,on,y", toString( arguments.value ) ) > 0;
	}

	private string function clipped( required string value, required numeric maxLen ){
		return left( trim( arguments.value ), arguments.maxLen );
	}

}
