/**
 * One audit run.
 *
 * Carries its own counts rather than deriving them from the issues table. A
 * report that lists twenty runs would otherwise be twenty aggregate queries,
 * and the counts never change once a run has finished — there is nothing to
 * keep in step.
 */
component accessors="true" {

	property name="id"           type="numeric";
	property name="siteId"       type="numeric";
	property name="status"       type="string";
	property name="startedAt";
	property name="finishedAt";
	property name="heartbeatAt";
	property name="urlCount"     type="numeric";
	property name="queuedCount"  type="numeric";
	property name="errorCount"   type="numeric";
	property name="warningCount" type="numeric";
	property name="noticeCount"  type="numeric";
	property name="note"         type="string";
	property name="runBy"        type="numeric";
	property name="createdAt";
	property name="updatedAt";

	boolean function isFinished(){
		return ( variables.status ?: "" ) == "finished";
	}

	boolean function isRunning(){
		return ( variables.status ?: "" ) == "running";
	}

	boolean function isFailed(){
		return ( variables.status ?: "" ) == "failed";
	}

	numeric function getIssueCount(){
		return val( variables.errorCount ?: 0 )
			+ val( variables.warningCount ?: 0 )
			+ val( variables.noticeCount ?: 0 );
	}

	/**
	 * How long the run took, in seconds, or an empty string while it is still
	 * going. A reader wants "took 14s", not two timestamps to subtract.
	 */
	string function getDuration(){
		if ( isNull( variables.finishedAt ) || isNull( variables.startedAt ) ) {
			return "";
		}

		return numberFormat( dateDiff( "s", variables.startedAt, variables.finishedAt ), "0" ) & "s";
	}

}
