/**
 * Shared plumbing for relational repositories.
 *
 * Exists only to keep three repositories from carrying identical copies of the
 * generated-key and unique-violation logic. It holds no domain knowledge and
 * no query of its own.
 */
component accessors="true" {

	// QueryBuilder is stateful, so a provider hands back a fresh one per call.
	property name="query"   inject="provider:QueryBuilder@qb";
	property name="wirebox" inject="wirebox";

	/**
	 * `queryExecute` reports the identity column under different keys depending
	 * on the engine and driver, so check the ones MySQL is known to use.
	 *
	 * @insertResult The struct returned by a qb insert.
	 * @table        Table name, used only for the error message.
	 */
	numeric function generatedKey( required struct insertResult, required string table ){
		// qb hands back `{ result : <queryExecute result>, query : <query> }`,
		// so unwrap before looking for the identity value.
		var result = structKeyExists( arguments.insertResult, "result" )
			? arguments.insertResult.result
			: arguments.insertResult;

		for ( var key in [ "generatedKey", "generated_key", "IDENTITYCOL", "ROWID" ] ) {
			if ( structKeyExists( result, key ) && len( result[ key ] ) ) {
				return val( result[ key ] );
			}
		}

		throw(
			type    = "Tenancy.MissingGeneratedKey",
			message = "The insert into `#arguments.table#` succeeded but returned no generated key."
		);
	}

	/**
	 * Did this error come from a unique index?
	 *
	 * The JDBC driver exposes no portable code, so we match on MySQL's 1062
	 * duplicate-entry text. SQLSTATE alone is not enough: unique violations and
	 * foreign key violations both report 23000, and this project needs to tell
	 * them apart — a cross-tenant role assignment must surface as an error, not
	 * be mistaken for a harmless duplicate.
	 *
	 * Used only to translate an expected collision into a typed error. Anything
	 * we cannot positively identify is rethrown untouched.
	 */
	boolean function isUniqueViolation( required any error ){
		var haystack = errorText( arguments.error );

		return find( "duplicate entry", haystack ) > 0 || find( "1062", haystack ) > 0;
	}

	/**
	 * Did this error come from a foreign key constraint?
	 *
	 * MySQL 1452 on insert/update, 1451 on delete.
	 */
	boolean function isForeignKeyViolation( required any error ){
		var haystack = errorText( arguments.error );

		return find( "foreign key constraint fails", haystack ) > 0
			|| find( "1452", haystack ) > 0
			|| find( "1451", haystack ) > 0;
	}

	private string function errorText( required any error ){
		return lCase(
			( arguments.error.message ?: "" ) & " " &
			( arguments.error.detail ?: "" ) & " " &
			( arguments.error.sqlstate ?: "" )
		);
	}

}
