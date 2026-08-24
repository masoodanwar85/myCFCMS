/**
 * Page arithmetic. Off-by-one here means either unreachable content or a page
 * of nothing, and both look like the site is broken.
 */
component extends="coldbox.system.testing.BaseTestCase" appMapping="/app" {

	function beforeAll(){
		super.beforeAll();
		variables.pager = getInstance( "Paginator@core" );
	}

	function afterAll(){
		super.afterAll();
	}

	function run(){
		describe( "Paginator", function(){

			describe( "arithmetic", function(){

				it( "splits records into pages", function(){
					var p = pager.paginate( total = 35, page = 1, perPage = 10 );

					expect( p.totalPages ).toBe( 4 );
					expect( p.offset ).toBe( 0 );
					expect( p.firstRecord ).toBe( 1 );
					expect( p.lastRecord ).toBe( 10 );
				} );

				it( "offsets correctly on a later page", function(){
					var p = pager.paginate( total = 35, page = 3, perPage = 10 );

					expect( p.offset ).toBe( 20 );
					expect( p.firstRecord ).toBe( 21 );
					expect( p.lastRecord ).toBe( 30 );
				} );

				it( "reports a short last page honestly", function(){
					var p = pager.paginate( total = 35, page = 4, perPage = 10 );

					expect( p.lastRecord ).toBe( 35 );
					expect( p.isLast ).toBeTrue();
					expect( p.hasNext ).toBeFalse();
				} );

				it( "handles an exact multiple without inventing an empty page", function(){
					expect( pager.paginate( total = 30, perPage = 10 ).totalPages ).toBe( 3 );
				} );

				it( "treats an empty list as one valid, empty page", function(){
					var p = pager.paginate( total = 0, page = 1, perPage = 10 );

					expect( p.totalPages ).toBe( 0 );
					expect( p.isValidPage ).toBeTrue();
					expect( p.firstRecord ).toBe( 0 );
					expect( p.lastRecord ).toBe( 0 );
				} );

				it( "needs no pager when everything fits on one page", function(){
					var p = pager.paginate( total = 8, perPage = 10 );

					expect( p.totalPages ).toBe( 1 );
					expect( p.pages ).toBeEmpty();
				} );

			} );

			describe( "refusing a page that does not exist", function(){

				it( "rejects a page past the end", function(){
					expect( pager.paginate( total = 35, page = 5, perPage = 10 ).isValidPage ).toBeFalse();
				} );

				it( "rejects zero and negatives", function(){
					expect( pager.paginate( total = 35, page = 0, perPage = 10 ).isValidPage ).toBeFalse();
					expect( pager.paginate( total = 35, page = -3, perPage = 10 ).isValidPage ).toBeFalse();
				} );

				it( "still clamps the arithmetic so a caller that ignores the flag is safe", function(){
					var p = pager.paginate( total = 35, page = 99, perPage = 10 );

					expect( p.page ).toBe( 4 );
					expect( p.offset ).toBe( 30 );
					expect( p.requestedPage ).toBe( 99 );
				} );

			} );

			describe( "the page window", function(){

				it( "lists every page when there are few", function(){
					expect( pager.paginate( total = 35, page = 1, perPage = 10 ).pages ).toBe( [ 1, 2, 3, 4 ] );
				} );

				it( "elides the middle of a long range", function(){
					var p = pager.paginate( total = 200, page = 7, perPage = 10 );

					// Zero stands in for a gap the view renders as an ellipsis.
					expect( p.pages ).toBe( [ 1, 0, 5, 6, 7, 8, 9, 0, 20 ] );
				} );

				it( "always keeps the first and last page reachable", function(){
					var p = pager.paginate( total = 500, page = 25, perPage = 10 );

					expect( p.pages[ 1 ] ).toBe( 1 );
					expect( p.pages[ p.pages.len() ] ).toBe( 50 );
				} );

			} );

			describe( "guarding its inputs", function(){

				it( "caps the page size so a caller cannot ask for everything", function(){
					expect( pager.paginate( total = 10000, perPage = 99999 ).perPage ).toBe( 100 );
				} );

				it( "refuses a page size below one", function(){
					expect( pager.paginate( total = 10, perPage = 0 ).perPage ).toBe( 1 );
				} );

				it( "reads a page number from untrusted input", function(){
					expect( pager.readPage( "3" ) ).toBe( 3 );
					expect( pager.readPage( "abc" ) ).toBe( 1 );
					expect( pager.readPage( "-2" ) ).toBe( 1 );
					expect( pager.readPage( "" ) ).toBe( 1 );
					expect( pager.readPage() ).toBe( 1 );
				} );

			} );

		} );
	}

}
