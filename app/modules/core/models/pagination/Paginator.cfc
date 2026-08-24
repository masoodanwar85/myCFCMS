/**
 * Page arithmetic, in one place.
 *
 * Lists across the CMS were either unbounded — the admin fetched every blog post
 * a site had ever written to render one screen — or silently truncated, which is
 * worse: the contact inbox stopped at 100 messages and the archive stopped at
 * ten posts, with nothing on the page to say more existed or any URL that could
 * reach them. Content became unreachable rather than merely inconvenient.
 *
 * Returns a plain struct rather than an object, so a theme written by someone
 * outside this project can read it without knowing any of our types.
 */
component singleton {

	variables.DEFAULT_PER_PAGE = 10;
	variables.MAX_PER_PAGE     = 100;

	/**
	 * @total   How many records exist in total.
	 * @page    The requested page, 1-based.
	 * @perPage Records per page. Capped, so a caller cannot ask for everything.
	 * @window  How many page numbers to show either side of the current one.
	 *
	 * @return  A struct describing the page, including `isValidPage`.
	 */
	struct function paginate(
		required numeric total,
		numeric page    = 1,
		numeric perPage = variables.DEFAULT_PER_PAGE,
		numeric window  = 2
	){
		// Locals must not reuse an argument's name: ColdFusion rejects
		// `var total` outright when `total` is an argument.
		var recordCount = max( 0, int( arguments.total ) );
		var size        = min( variables.MAX_PER_PAGE, max( 1, int( arguments.perPage ) ) );
		var requested   = int( arguments.page );

		var totalPages = recordCount == 0 ? 0 : ceiling( recordCount / size );

		// An empty list still has a legitimate first page. Anything beyond the
		// last page is not a page at all — the caller should treat it as a 404
		// rather than quietly serving page one, which would be a different
		// page's content under this page's URL.
		var isValid = requested >= 1 && ( requested == 1 || requested <= totalPages );

		// Clamped only for the arithmetic below; `isValidPage` still reports the
		// truth so the caller can refuse.
		var current = max( 1, min( requested, max( 1, totalPages ) ) );

		return {
			"page"         : current,
			"requestedPage": requested,
			"isValidPage"  : isValid,
			"perPage"      : size,
			"total"        : recordCount,
			"totalPages"   : totalPages,
			"offset"       : ( current - 1 ) * size,
			"isFirst"      : current <= 1,
			"isLast"       : current >= totalPages,
			"hasPrevious"  : current > 1,
			"hasNext"      : current < totalPages,
			"previousPage" : max( 1, current - 1 ),
			"nextPage"     : min( max( 1, totalPages ), current + 1 ),
			"pages"        : pageWindow( current, totalPages, arguments.window ),
			"firstRecord"  : recordCount == 0 ? 0 : ( ( current - 1 ) * size ) + 1,
			"lastRecord"   : min( recordCount, current * size )
		};
	}

	/**
	 * The page numbers worth showing.
	 *
	 * A site with two hundred pages of posts should not render two hundred
	 * links, so this returns a window around the current page plus the first
	 * and last, with `0` standing in for a gap the caller renders as an ellipsis.
	 */
	array function pageWindow(
		required numeric current,
		required numeric totalPages,
		numeric window = 2
	){
		if ( arguments.totalPages <= 1 ) {
			return [];
		}

		var wanted = {};
		wanted[ 1 ] = true;
		wanted[ arguments.totalPages ] = true;

		for ( var i = arguments.current - arguments.window; i <= arguments.current + arguments.window; i++ ) {
			if ( i >= 1 && i <= arguments.totalPages ) {
				wanted[ i ] = true;
			}
		}

		var numbers = wanted.keyArray().map( ( n ) => int( n ) ).sort( ( a, b ) => a - b );
		var result  = [];
		var last    = 0;

		for ( var n in numbers ) {
			if ( last && n > last + 1 ) {
				result.append( 0 );
			}
			result.append( n );
			last = n;
		}

		return result;
	}

	numeric function getDefaultPerPage(){
		return variables.DEFAULT_PER_PAGE;
	}

	/**
	 * Read a page number from user input without trusting it.
	 */
	numeric function readPage( any value = 1 ){
		var candidate = trim( arguments.value ?: "" );

		if ( !isValid( "integer", candidate ) || val( candidate ) < 1 ) {
			return 1;
		}

		return val( candidate );
	}

}
