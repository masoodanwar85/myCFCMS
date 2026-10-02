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
	property name="kind"             type="string";
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

	boolean function isDocument(){
		return getKind() == "document";
	}

	/**
	 * `image` or `document`.
	 *
	 * Derived from the mime type when the column has not been set, so an item
	 * built in memory — a spec, or a row read before the `kind` column existed
	 * — classifies the same way the database would. The stored value wins when
	 * there is one, because that is what the queries filter on.
	 */
	string function getKind(){
		if ( len( variables.kind ?: "" ) ) {
			return variables.kind;
		}

		// The mime test is repeated from `isImage()` rather than calling it.
		// `isImage` is a ColdFusion built-in, and an unqualified call to it from
		// inside this component resolves to the BIF, not to the method —
		// "Parameter validation error for isImage function", followed by this
		// component dropping out of WireBox entirely.
		return left( variables.mimeType ?: "", 6 ) == "image/" ? "image" : "document";
	}

	/**
	 * How to describe the file to a reader: `PDF`, `Word document`, `Excel
	 * spreadsheet`. Falls back to the bare extension, which is still more use
	 * than "file".
	 */
	string function getTypeLabel(){
		var names = {
			"pdf"  : "PDF",
			"doc"  : "Word document",
			"docx" : "Word document",
			"xls"  : "Excel spreadsheet",
			"xlsx" : "Excel spreadsheet",
			"ppt"  : "PowerPoint presentation",
			"pptx" : "PowerPoint presentation",
			"csv"  : "CSV",
			"txt"  : "Text file",
			"zip"  : "ZIP archive"
		};

		// `structKeyExists`, not `?:` on a bracket lookup: a missing struct key
		// raises on Adobe rather than resolving to null.
		var ext = lCase( variables.extension ?: "" );

		if ( structKeyExists( names, ext ) ) {
			return names[ ext ];
		}

		return len( ext ) ? uCase( ext ) : "File";
	}

	/**
	 * What a link to this file should say when the author gave no label.
	 *
	 * The title first, because somebody chose it; the uploaded filename
	 * otherwise. Never the generated filename — nobody means to publish a link
	 * reading `terms-a1b2c3d4.pdf`.
	 */
	string function getEffectiveLabel(){
		if ( len( trim( variables.title ?: "" ) ) ) {
			return trim( variables.title );
		}

		var original = trim( variables.originalFilename ?: "" );

		return len( original ) ? original : "Download";
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
			// The picker draws a thumbnail for one and a filename with a type
			// badge for the other, so it needs to know which without parsing
			// the mime type in JavaScript.
			"kind"      : getKind(),
			"typeLabel" : getTypeLabel(),
			"label"     : getEffectiveLabel(),
			"byteSize"  : variables.byteSize,
			"humanSize" : getHumanSize(),
			"width"     : variables.width ?: "",
			"height"    : variables.height ?: "",
			"altText"   : variables.altText ?: "",
			"title"     : variables.title ?: "",
			"createdAt" : isNull( variables.createdAt ) ? "" : dateTimeFormat( variables.createdAt, "iso" )
		};
	}

}
