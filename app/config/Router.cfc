component {

    function configure() {
        /**
         * --------------------------------------------------------------------------
         * App Routes
         * --------------------------------------------------------------------------
         * Here is where you can register the routes for your web application!
         * Go get Funky!
         */

        // A nice healthcheck route example
        route('/healthcheck', function(event, rc, prc) {
            return 'Ok!';
        });

        // A nice RESTFul Route example
        route('/api/echo', function(event, rc, prc) {
            return {'error': false, 'data': 'Welcome to my awesome API!'};
        });

        // @app_routes@

        /**
         * --------------------------------------------------------------------------
         * Framework-addressable routes
         * --------------------------------------------------------------------------
         * Anything the application itself serves must be claimed here, above the
         * catch-all. The scaffold's conventions route (`:handler/:action?`) has
         * been replaced by this explicit one: in a CMS the public URL space
         * belongs to tenant content, and a conventions route would swallow
         * `/about` as a handler named "about" before the site ever saw it.
         *
         * Admin and API areas will claim reserved prefixes here in the same way.
         */
        route('/main/:action?').toHandler('main');

        /**
         * --------------------------------------------------------------------------
         * Public site catch-all
         * --------------------------------------------------------------------------
         * Must stay last. It claims every remaining URL and hands it to Core's
         * front controller, which resolves it against the current tenant's
         * content. `/` arrives as an empty path, which the Pages resolver reads
         * as the site's home page.
         */
        route('/').to('core:Frontend.index');
        route('/:path*').to('core:Frontend.index');
    }

}
