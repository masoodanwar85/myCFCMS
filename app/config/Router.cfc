component {

    function configure() {
        /**
         * --------------------------------------------------------------------------
         * Extension detection
         * --------------------------------------------------------------------------
         * ColdBox strips a trailing `.pdf`, `.html`, `.xml`, `.json`, `.rss` or
         * `.cfm` from a URL and treats it as a requested format. That is useful
         * for an API and actively harmful here: a media file at
         * `/media/2026/08/notes.pdf` arrived with its extension removed and
         * could not be found, and a page whose slug happened to end in `.html`
         * would be mangled the same way.
         *
         * Nothing in this application uses format detection, so paths are left
         * exactly as they were requested.
         */
        setExtensionDetection( false );

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

        /**
         * --------------------------------------------------------------------------
         * The REST API
         * --------------------------------------------------------------------------
         * Versioned in the path. A version in a header is tidier in theory and
         * worse in practice: a URL you cannot paste into curl, a browser or a
         * bug report is a URL nobody can talk about.
         *
         * Core claims `/api/v1` itself; each module claims its own resources
         * beneath it from its own ModuleConfig, so installing a module adds its
         * endpoints without a line changing here.
         *
         * Declared above the public catch-all, which would otherwise hand
         * `/api/...` to a content resolver looking for a page.
         */
        // One registration only: ColdBox normalises the trailing slash, so
        // registering `/api/v1` and `/api/v1/` separately merges them into a
        // single malformed route that matches and then dispatches nowhere.
        route('/api/v1').to('core:Api.index');

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
        /**
         * Uploaded files. Served by Core because they live outside the webroot
         * and must be scoped to the site that owns them.
         */
        route('/media/:path*').to('core:Media.serve');

        /**
         * --------------------------------------------------------------------------
         * What a crawler asks for
         * --------------------------------------------------------------------------
         * Handlers rather than files in `public/`, because both are per tenant:
         * one static `robots.txt` in the webroot would be shared by every site
         * on the installation, so a staging tenant could not be closed to
         * crawlers without closing every client's site with it.
         *
         * The scaffold's `public/robots.txt` was deleted for exactly that
         * reason — a file there is served by the web server before any route is
         * consulted, and would have silently shadowed this.
         */
        route('/sitemap.xml').to('core:Seo.sitemap');
        route('/robots.txt').to('core:Seo.robots');

        route('/').to('core:Frontend.index');
        route('/:path*').to('core:Frontend.index');
    }

}
