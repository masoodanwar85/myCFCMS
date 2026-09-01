component {

    /**
     * Configure the ColdBox App For Production
     */
    function configure() {
        /**
         * --------------------------------------------------------------------------
         * ColdBox Directives
         * --------------------------------------------------------------------------
         * Here you can configure ColdBox for operation. Remember tha these directives below
         * are for PRODUCTION. If you want different settings for other environments make sure
         * you create the appropriate functions and define the environment in your .env or
         * in the `environments` struct.
         */
        variables.coldbox = {
            // Application Setup
            appName: getSystemSetting('APPNAME', 'Your app name here'),
            eventName: 'event',
            // Development Settings
            reinitPassword: '',
            reinitKey: 'fwreinit',
            handlersIndexAutoReload: true,
            // Implicit Events
            defaultEvent: '',
            requestStartHandler: 'Main.onRequestStart',
            requestEndHandler: '',
            applicationStartHandler: 'Main.onAppInit',
            applicationEndHandler: '',
            sessionStartHandler: '',
            sessionEndHandler: '',
            missingTemplateHandler: '',
            // Extension Points
            applicationHelper: '/app/helpers/ApplicationHelper.cfm',
            viewsHelper: '',
            modulesExternalLocation: ['/modules'],
            viewsExternalLocation: '',
            layoutsExternalLocation: '',
            handlersExternalLocation: '',
            requestContextDecorator: '',
            controllerDecorator: '',
            // Error/Exception Handling
            invalidHTTPMethodHandler: '',
            exceptionHandler: 'main.onException',
            invalidEventHandler: '',
            // Set for every environment on purpose: the template itself decides
            // how much detail to show, based on who is asking. See the comment
            // block in that file — `.env` is not read outside CommandBox, and
            // Whoops cannot load its assets outside the CommandBox webroot.
            customErrorTemplate: '/app/exceptions/BugReport.cfm',
            // Application Aspects
            handlerCaching: false,
            eventCaching: false,
            viewCaching: false,
            // Will automatically do a mapDirectory() on your `models` for you.
            autoMapModels: true,
            // Auto converts a json body payload into the RC
            jsonPayloadToRC: true
        };

        /**
         * --------------------------------------------------------------------------
         * Custom Settings
         * --------------------------------------------------------------------------
         */
        variables.settings = {};

        /**
         * --------------------------------------------------------------------------
         * Environment Detection
         * --------------------------------------------------------------------------
         * By default we look in your `.env` file for an `environment` key, if not,
         * then we look into this structure or if you have a function called `detectEnvironment()`
         * If you use this setting, then each key is the name of the environment and the value is
         * the regex patterns to match against cgi.http_host.
         *
         * Uncomment to use, but make sure your .env ENVIRONMENT key is also removed.
         */
        // environments = { development : "localhost,^127\.0\.0\.1" };

        /**
         * --------------------------------------------------------------------------
         * Module Loading Directives
         * --------------------------------------------------------------------------
         */
        variables.modules = {
            // An array of modules names to load, empty means all of them
            include: [],
            // An array of modules names to NOT load, empty means none
            exclude: []
        };

        /**
         * --------------------------------------------------------------------------
         * Application Logging (https://logbox.ortusbooks.com)
         * --------------------------------------------------------------------------
         * By Default we log to the console, but you can add many appenders or destinations to log to.
         * You can also choose the logging level of the root logger, or even the actual appender.
         */
        variables.logBox = {
            // Define Appenders
            appenders: {
                consolelog: {class: 'coldbox.system.logging.appenders.ConsoleAppender'},
                filelog: {
                    class: 'coldbox.system.logging.appenders.RollingFileAppender',
                    properties: {filename: 'app', filePath: '/app/logs'}
                }
            },
            // Root Logger
            root: {levelmax: 'INFO', appenders: '*'},
            // Implicit Level Categories
            info: ['coldbox.system']
        };

        /**
         * --------------------------------------------------------------------------
         * Layout Settings
         * --------------------------------------------------------------------------
         */
        variables.layoutSettings = {defaultLayout: '', defaultView: ''};

        /**
         * --------------------------------------------------------------------------
         * Custom Interception Points
         * --------------------------------------------------------------------------
         */
        variables.interceptorSettings = {customInterceptionPoints: []};

        /**
         * --------------------------------------------------------------------------
         * Application Interceptors
         * --------------------------------------------------------------------------
         * Remember that the order of declaration is the order they will be registered and fired
         */
        variables.interceptors = [];

        /**
         * --------------------------------------------------------------------------
         * Module Settings
         * --------------------------------------------------------------------------
         * Each module has it's own configuration structures, so make sure you follow
         * the module's instructions on settings.
         *
         * Each key is the name of the module:
         *
         * myModule = {
         *
         * }
         */
        variables.moduleSettings = {};

        /**
         * --------------------------------------------------------------------------
         * Flash Scope Settings
         * --------------------------------------------------------------------------
         * The available scopes are : session, client, cluster, ColdBoxCache, or a full instantiation CFC path
         */
        variables.flash = {
            scope: 'session',
            properties: {}, // constructor properties for the flash scope implementation
            inflateToRC: true, // automatically inflate flash data into the RC scope
            inflateToPRC: false, // automatically inflate flash data into the PRC scope
            autoPurge: true, // automatically purge flash data for you
            autoSave: true // automatically save flash scopes at end of a request and on relocations.
        };

        /**
         * --------------------------------------------------------------------------
         * App Conventions
         * --------------------------------------------------------------------------
         */
        variables.conventions = {
            handlersLocation: 'handlers',
            viewsLocation: 'views',
            layoutsLocation: 'layouts',
            modelsLocation: 'models',
            eventAction: 'index'
        };
    }

    /**
     * Development environment
     *
     * Only ever reached under CommandBox: ColdBox resolves the environment from
     * `getSystemSetting( "ENVIRONMENT" )`, which reads JVM system properties and
     * OS environment variables and never the `.env` file — CommandBox is what
     * loads `.env` into the JVM at `server start`.
     *
     * Do NOT force this on with a JVM argument on a server running under Apache
     * and ColdFusion. Whoops pulls its CSS and JS from
     * `/coldbox/system/exceptions/`, a path made web-reachable by the alias in
     * `server.json`; `lib/coldbox` is outside the webroot, so on a real web
     * server those assets 404 and Whoops renders as an unusable shell. There,
     * the gated `/app/exceptions/BugReport.cfm` configured above is what gives
     * you full detail — and only to an allowlisted address.
     */
    function development() {
        variables.coldbox.customErrorTemplate = '/coldbox/system/exceptions/Whoops.cfm'; // interactive bug report
    }

}
