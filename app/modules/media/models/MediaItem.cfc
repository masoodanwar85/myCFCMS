/**
 * One uploaded file.
 */
component accessors="true" {

	property name="id"               type="numeric";
	property name="siteId"           type="numeric";
	property name="filename"         type="string";
	property name="originalFilename" type="string";
	property name="storedPath"       type="string";
	property name="extension"        type="string";
	property name="mimeType"         type="string";
	property name="byteSize"         type="numeric";
	property name="width"            type="numeric";
	property name="height"           type="numeric";
	property name="altText"          type="string";
	property name="title"            type="string";
	property name="uploadedBy"       type="numeric";
	property name="createdAt";
	property name="updatedAt";

	boolean function isImage(){
		return left( variables.mimeType ?: "", 6 ) == "image/";
	}

	/**
	 * The public URL. Tenant-scoped by the handler that serves it, so the path
	 * carries no site id.
	 */
	string function getUrl(){
		return "/media/" & variables.storedPath;
	}

	/**
	 * What a screen reader should say. Falls back to nothing rather than to the
	 * filename: `DSC_0042.jpg` read aloud is worse than silence.
	 */
	string function getEffectiveAlt(){
		return trim( variables.altText ?: "" );
	}

	string function getHumanSize(){
		var bytes = variables.byteSize ?: 0;

		if ( bytes < 1024 ) {
			return bytes & " B";
		}
		if ( bytes < 1048576 ) {
			return numberFormat( bytes / 1024, "9.9" ) & " KB";
		}

		return numberFormat( bytes / 1048576, "9.9" ) & " MB";
	}

	struct function getMemento(){
		return {
			"id"        : variables.id,
			"url"       : getUrl(),
			"filename"  : variables.originalFilename,
			"mimeType"  : variables.mimeType,
			"byteSize"  : variables.byteSize,
			"width"     : variables.width ?: "",
			"height"    : variables.height ?: "",
			"altText"   : variables.altText ?: "",
			"title"     : variables.title ?: "",
			"createdAt" : isNull( variables.createdAt ) ? "" : dateTimeFormat( variables.createdAt, "iso" )
		};
	}

}
