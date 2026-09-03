/**
 * What kinds of field a form may have.
 *
 * One place that answers three questions the rest of the module keeps asking:
 * is this a real type, does it take a list of options, and how is a value of
 * this type validated. Scattering that across the builder, the validator and
 * the renderer is how the three drift apart — a type added to the dropdown but
 * not to the validator is a field that accepts anything.
 *
 * Deliberately not a database table. These are code: each one needs a matching
 * branch in the renderer and the validator, so a type nobody has written those
 * for cannot be usefully added by an author at runtime.
 *
 * File uploads are absent on purpose. They need storage quotas, type sniffing,
 * a retention policy and a way to serve the result safely — all of which the
 * media library already solves for a *logged-in* user and none of which is
 * solved for an anonymous one.
 */
component singleton {

	variables.TYPES = [
		{ key : "text",     label : "Single line text", hasOptions : false, multiValue : false },
		{ key : "textarea", label : "Paragraph",        hasOptions : false, multiValue : false },
		{ key : "email",    label : "Email address",    hasOptions : false, multiValue : false },
		{ key : "tel",      label : "Phone number",     hasOptions : false, multiValue : false },
		{ key : "number",   label : "Number",           hasOptions : false, multiValue : false },
		{ key : "date",     label : "Date",             hasOptions : false, multiValue : false },
		{ key : "select",   label : "Dropdown",         hasOptions : true,  multiValue : false },
		{ key : "radio",    label : "Choose one",       hasOptions : true,  multiValue : false },
		{ key : "checkbox", label : "Choose any",       hasOptions : true,  multiValue : true }
	];

	array function all(){
		return variables.TYPES;
	}

	boolean function isValid( required string type ){
		return !isNull( findType( arguments.type ) );
	}

	boolean function hasOptions( required string type ){
		var found = findType( arguments.type );

		return isNull( found ) ? false : found.hasOptions;
	}

	/**
	 * Whether a field of this type can hold more than one answer, which decides
	 * whether the posted value arrives as a list.
	 */
	boolean function isMultiValue( required string type ){
		var found = findType( arguments.type );

		return isNull( found ) ? false : found.multiValue;
	}

	string function labelFor( required string type ){
		var found = findType( arguments.type );

		return isNull( found ) ? arguments.type : found.label;
	}

	/**
	 * The `type` attribute an `<input>` should carry. Types that are not inputs
	 * at all — textarea, select, radio, checkbox — are the renderer's problem,
	 * not this one's.
	 */
	string function inputTypeFor( required string type ){
		switch ( arguments.type ) {
			case "email":  return "email";
			case "tel":    return "tel";
			case "number": return "number";
			case "date":   return "date";
			default:       return "text";
		}
	}

	/**
	 * Not named `find`: ColdFusion has a built-in `find( substring, string )`,
	 * and a one-argument method of that name fails to compile with "Parameter
	 * validation error for the FIND function" — which WireBox then reports as
	 * an unrelated instance being missing.
	 */
	private function findType( required string type ){
		var wanted = lCase( trim( arguments.type ) );

		for ( var candidate in variables.TYPES ) {
			if ( candidate.key == wanted ) {
				return candidate;
			}
		}

		return;
	}

}
