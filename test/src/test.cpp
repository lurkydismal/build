#include "test.hpp"

#if defined( TESTS )

#include <format>
#include <gsl/pointers>
#include <iterator>
#include <memory>
#include <print>
#include <ranges>
#include <string>

#include "stdcolor.hpp"

size_t g_seed;

class CustomPrinter : public testing::TestEventListener {
public:
    // Forward events you don't care about to a default listener if you want.
    explicit CustomPrinter( testing::TestEventListener* _defaultListener )
        : _defaultListener( _defaultListener ) {}

    // TODO: Decide if program start or iteration start
    void OnTestProgramStart(
        [[maybe_unused]] const testing::UnitTest& _unitTest ) override {}

    // Print all tests that will run and seed
    void OnTestIterationStart( const testing::UnitTest& _unitTest,
                               int _iteration ) override {
        const size_t l_suiteAmount = _unitTest.test_suite_to_run_count();

        g_seed = _unitTest.random_seed();

        const std::string l_iteration =
            ( ( _iteration > 0 ) ? ( std::format( " #{}", _iteration ) )
                                 : ( "" ) );

        std::println(
            "{}--- Running {} tests from {} {} with seed [{}]{} ---{}",
            stdfunc::color::g_yellow, _unitTest.test_to_run_count(),
            l_suiteAmount,
            ( ( l_suiteAmount > 1 ) ? ( "suites" ) : ( "suite" ) ), g_seed,
            l_iteration, stdfunc::color::g_reset );
    }

    void OnEnvironmentsSetUpStart(
        [[maybe_unused]] const testing::UnitTest& _unitTest ) override {}

    void OnEnvironmentsSetUpEnd(
        [[maybe_unused]] const testing::UnitTest& _unitTest ) override {}

    // Print all tests that will run in suite and suite name
    void OnTestSuiteStart( const testing::TestSuite& _testSuite ) override {
        const std::string l_suiteName = _testSuite.name();

        std::println( "{}--- Running {} tests in [{}] ---{}",
                      stdfunc::color::g_yellow, _testSuite.test_to_run_count(),
                      l_suiteName, stdfunc::color::g_reset );
    }

    // Print test suite and test name
    void OnTestStart( const testing::TestInfo& _testInfo ) override {
        std::println( "{}Running {}.{} test...{}", stdfunc::color::g_cyanLight,
                      _testInfo.test_suite_name(), _testInfo.name(),
                      stdfunc::color::g_reset );
    }

    // TODO: Implement
    void OnTestDisabled( const testing::TestInfo& _testInfo ) override {
        std::println( "[CUSTOM]: {}", "OnTestDisabled" );
        _defaultListener->OnTestDisabled( _testInfo );
    }

    // Print test result, where, summary
    void OnTestPartResult( const testing::TestPartResult& _result ) override {
        std::string l_result;

        if ( _result.passed() ) {
            l_result = std::format( "{}[PASSED]{}", stdfunc::color::g_green,
                                    stdfunc::color::g_reset );

        } else if ( _result.skipped() ) {
            l_result =
                std::format( "{}[SKIPPED]{}", stdfunc::color::g_blueLight,
                             stdfunc::color::g_reset );

        } else {
            l_result = std::format( "{}[FAILED]{}", stdfunc::color::g_red,
                                    stdfunc::color::g_reset );
        }

        const std::string l_where =
            std::format( "{}:{}", _result.file_name(), _result.line_number() );

        std::string l_message;

        if ( !_result.passed() ) {
            l_message =
                std::format( "{}{}{}", stdfunc::color::g_purpleLight,
                             _result.message(), stdfunc::color::g_reset );
        }

        std::print( "{} {}\n{}", l_result, l_where, l_message );
    }

    // Print test name and elapsed time
    void OnTestEnd( const testing::TestInfo& _testInfo ) override {
        const std::string l_result =
            std::format( "{}[FINISHED]{}", stdfunc::color::g_green,
                         stdfunc::color::g_reset );

        const std::string l_name = std::format(
            "{}:{}", _testInfo.test_suite_name(), _testInfo.name() );

        std::println( "{} {} in {} ms", l_result, l_name,
                      _testInfo.result()->elapsed_time() );
    }

    // Print test suite and elapsed time
    void OnTestSuiteEnd( const testing::TestSuite& _testSuite ) override {
        std::println( "{}--- Finished running [{}] in {} ms ---{}",
                      stdfunc::color::g_yellow, _testSuite.name(),
                      _testSuite.elapsed_time(), stdfunc::color::g_reset );
    }

    void OnEnvironmentsTearDownStart(
        [[maybe_unused]] const testing::UnitTest& _unitTest ) override {}

    void OnEnvironmentsTearDownEnd(
        [[maybe_unused]] const testing::UnitTest& _unitTest ) override {}

    // Print passed and failed amount, and test names with suite
    void OnTestIterationEnd( const testing::UnitTest& _unitTest,
                             int _iteration ) override {
        const std::string l_iteration =
            ( ( _iteration > 0 ) ? ( std::format( " #{}", _iteration ) )
                                 : ( "" ) );

        std::println( "{}--- Test Summary{} ---{}", stdfunc::color::g_yellow,
                      l_iteration, stdfunc::color::g_reset );

        const size_t l_passedAmount = _unitTest.successful_test_count();

        if ( l_passedAmount ) {
            std::println( "{}Passed: {}{}", stdfunc::color::g_green,
                          l_passedAmount, stdfunc::color::g_reset );
        }

        const size_t l_failedAmount = _unitTest.failed_test_count();

        if ( l_failedAmount ) {
            std::println( "{}Failed: {}{}", stdfunc::color::g_red,
                          l_failedAmount, stdfunc::color::g_reset );

            std::string l_failedTests;
            l_failedTests.reserve( 100 );

            auto l_iterateTestSuites = [ & ]( auto _callback ) -> auto {
                for ( const gsl::not_null _testSuite :
                      std::views::iota(
                          size_t{}, static_cast< size_t >(
                                        _unitTest.total_test_suite_count() ) ) |
                          std::views::transform( [ & ]( auto _index ) -> auto {
                              return ( _unitTest.GetTestSuite( _index ) );
                          } ) ) {
                    _callback( _testSuite );
                }
            };

            const auto l_iterateTestInfos =
                [ & ]( gsl::not_null< const testing::TestSuite* > _testSuite,
                       auto _callback ) -> auto {
                for ( const gsl::not_null _testInfo :
                      std::views::iota( size_t{},
                                        static_cast< size_t >(
                                            _testSuite->total_test_count() ) ) |
                          std::views::transform( [ & ]( auto _index ) -> auto {
                              return ( _testSuite->GetTestInfo( _index ) );
                          } ) ) {
                    _callback( _testInfo );
                }
            };

            l_iterateTestSuites( [ & ]( auto _testSuite ) -> auto {
                l_iterateTestInfos(
                    _testSuite, [ & ]( auto _testInfo ) -> auto {
                        if ( _testInfo->result()->Failed() ) {
                            const std::string l_where = std::format(
                                "{}{}:{}{}", stdfunc::color::g_reset,
                                _testInfo->file(), _testInfo->line(),
                                stdfunc::color::g_red );

                            std::format_to( std::back_inserter( l_failedTests ),
                                            "\t{}.{} {}\n", _testSuite->name(),
                                            _testInfo->name(), l_where );
                        }
                    } );
            } );

            std::println( "{}{}{}", stdfunc::color::g_red, l_failedTests,
                          stdfunc::color::g_reset );
        }
    }

    void OnTestProgramEnd(
        [[maybe_unused]] const testing::UnitTest& _unitTest ) override {}

private:
    gsl::not_null< testing::TestEventListener* > _defaultListener;
};

auto main( int _argumentCount, char** _argumentsVector ) -> int {
    testing::InitGoogleTest( &_argumentCount, _argumentsVector );

#if !defined( TESTS_GTEST_PRINTER )

    // Grab the event listeners list
    testing::TestEventListeners& l_listeners =
        testing::UnitTest::GetInstance()->listeners();

    // Save default printer and replace it
    gsl::not_null l_defaultPrinter =
        l_listeners.Release( l_listeners.default_result_printer() );

    auto l_customPrinter =
        std::make_unique< CustomPrinter >( l_defaultPrinter );

    l_listeners.Append( l_customPrinter.release() );

#endif

    return ( RUN_ALL_TESTS() );
}

#endif
