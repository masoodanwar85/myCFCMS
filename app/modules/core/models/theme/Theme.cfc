/**
 * A theme: a directory of layouts and views a site renders through.
 *
 * State only. It knows where its templates live and which ones exist; it does
 * not render anything itself.
 */
component accessors="true" {

	property name="slug"        type="string";
	property name="title"       type="string";
	property name="version"     type="string";
	property name="description" type="string";

	// Mapped path, e.g. "/themes/default". Not a filesystem path, because
	// ColdBox renders templates through mappings.
	property name="mappedPath"  type="string";

	// Absolute filesystem path, used only for existence checks.
	property name="diskPath"    type="string";

	/**
	 * The mapped path of one of this theme's views, for the renderer.
	 */
	string function viewPath( required string view ){
		return variables.mappedPath & "/views/" & arguments.view;
	}

	string function layoutPath( required string layout = "main" ){
		return variables.mappedPath & "/layouts/" & arguments.layout;
	}

	boolean function hasView( required string view ){
		return fileExists( variables.diskPath & "/views/" & arguments.view & ".cfm" );
	}

	boolean function hasLayout( required string layout = "main" ){
		return fileExists( variables.diskPath & "/layouts/" & arguments.layout & ".cfm" );
	}

	struct function getMemento(){
		return {
			"slug"        : variables.slug,
			"title"       : variables.title,
			"version"     : variables.version ?: "",
			"description" : variables.description ?: ""
		};
	}

}
