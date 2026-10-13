/**
 * One finding, at one URL, from one run.
 *
 * `path` is text and `pageId` is a nullable convenience — see the migration for
 * why. The short version: not every audited URL is a page, and a finding is a
 * statement about what was true when the run happened.
 */
component accessors="true" {

	property name="id"        type="numeric";
	property name="auditId"   type="numeric";
	property name="siteId"    type="numeric";
	property name="path"      type="string";
	property name="pageId"    type="numeric";
	property name="checkId"   type="string";
	property name="severity"  type="string";
	property name="message"   type="string";
	property name="detail"    type="string";
	property name="createdAt";

	/**
	 * The URL as a reader recognises it: `/` for the home page, `/about` for
	 * the rest.
	 */
	string function getDisplayPath(){
		var clean = trim( variables.path ?: "" );

		return len( clean ) ? "/" & clean : "/";
	}

	boolean function isError(){
		return ( variables.severity ?: "" ) == "error";
	}

}
