/**
 * One field on a form. State only.
 */
component accessors="true" {

	property name="id"          type="numeric";
	property name="siteId"      type="numeric";
	property name="formId"      type="numeric";
	property name="fieldType"   type="string";

	/**
	 * What this field is called in the posted data and in a stored answer.
	 *
	 * Separate from the label, and stable. Renaming a label is a display
	 * change; changing this would orphan every answer already recorded under
	 * the old key.
	 */
	property name="fieldKey"    type="string";

	property name="label"       type="string";
	property name="placeholder" type="string";
	property name="helpText"    type="string";

	// Newline-separated, one option per line. A format an author can read and
	// repair by hand beats one that needs a parser to explain a syntax error.
	property name="optionsText" type="string";

	property name="isRequired"  type="boolean";
	property name="maxLength"   type="numeric";
	property name="sortOrder"   type="numeric";
	property name="createdAt";
	property name="updatedAt";

	function init(){
		variables.isRequired  = false;
		variables.sortOrder   = 0;
		variables.optionsText = "";

		return this;
	}

	/**
	 * The options as an array, blank lines dropped.
	 */
	array function getOptions(){
		var raw = trim( variables.optionsText ?: "" );

		if ( !len( raw ) ) {
			return [];
		}

		var cleaned = [];

		// The fourth argument is `multiCharacterDelimiter`, and passing `true`
		// here made "\n\r" one two-character delimiter rather than a set of
		// two — so nothing split on a plain newline and every option came back
		// as a single line. Left off, the delimiters are a character set, which
		// is what handles both Unix and Windows line endings.
		for ( var line in listToArray( raw, chr( 10 ) & chr( 13 ), false ) ) {
			var option = trim( line );

			if ( len( option ) ) {
				arrayAppend( cleaned, option );
			}
		}

		return cleaned;
	}

	struct function getMemento(){
		return {
			"id"          : variables.id,
			"formId"      : variables.formId,
			"fieldType"   : variables.fieldType,
			"fieldKey"    : variables.fieldKey,
			"label"       : variables.label,
			"placeholder" : variables.placeholder ?: "",
			"helpText"    : variables.helpText ?: "",
			"options"     : getOptions(),
			"isRequired"  : variables.isRequired,
			"sortOrder"   : variables.sortOrder
		};
	}

}
