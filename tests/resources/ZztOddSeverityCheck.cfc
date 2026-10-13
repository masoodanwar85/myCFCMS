/**
 * An SEO check returning a severity that is not one of the three, to prove the
 * registry records it as a notice rather than discarding the finding.
 */
component {
	array function inspect( required any document, required struct context ){
		return [ {
			"checkId"  : "zzt.odd",
			"severity" : "catastrophe",
			"message"  : "A finding with a severity nobody defined.",
			"detail"   : ""
		} ];
	}
}
