component extends="coldbox.system.EventHandler" {

    /**
     * Default Action
     */
    function index(event, rc, prc) {
        prc.welcomeMessage = 'Welcome to ColdBox!';
        event.setView('main/index');
    }

    /**
     * Produce some restfulf data
     */
    function data(event, rc, prc) {
        return [
            {'id': createUUID(), name: 'Luis'},
            {'id': createUUID(), name: 'JOe'},
            {'id': createUUID(), name: 'Bob'},
            {'id': createUUID(), name: 'Darth'}
        ];
    }


    /**
     * error
     */
    function error(event, rc, prc) {
        event.settttView('Main/error');
    }


    /**
     * Relocation example
     */
    function doSomething(event, rc, prc) {
        relocate('main.index');
    }

    /************************************** IMPLICIT ACTIONS *********************************************/

    function onAppInit(event, rc, prc) {
    }

    function onRequestStart(event, rc, prc) {
    }

    function onRequestEnd(event, rc, prc) {
    }

    function onSessionStart(event, rc, prc) {
    }

    function onSessionEnd(event, rc, prc) {
        var sessionScope = event.getValue('sessionReference');
        var applicationScope = event.getValue('applicationReference');
    }

    /**
     * Log every unhandled exception.
     *
     * This handler is registered as ColdBox's `exceptionHandler`, and that
     * carries a consequence worth stating plainly: when an exception handler is
     * configured and it returns without throwing, ColdBox skips its own
     * `appLogger.error()` call (Bootstrap.cfc, `processException`). An empty
     * handler therefore does not mean "log as usual" — it means the error is
     * shown to nobody and written nowhere. Logging here is what puts it back.
     *
     * In production this log is the *only* place a stack trace exists. Visitors
     * get `BugReport-Public.cfm`, which deliberately shows the exception type
     * and nothing else, and that is the correct thing for them to see.
     */
    function onException(event, rc, prc) {
        event.setHTTPHeader(statusCode = 500);

        // An ExceptionBean, not a raw cfcatch: read it through its getters.
        var exception = prc.exception;

        // Tie the trace to a request. A stack trace with no URL and no host is
        // markedly harder to act on, and on a multi-tenant application the host
        // is also which client hit it.
        var context = (cgi.request_method ?: "") & " " & (cgi.http_host ?: "") & (cgi.path_info ?: "");

        if (len(cgi.query_string ?: "")) {
            context &= "?" & cgi.query_string;
        }

        log.error(
            "Unhandled #exception.getType()#: #exception.getMessage()# #exception.getDetail()# [#trim(context)#]",
            exception.getExceptionStruct()
        );
    }

}
