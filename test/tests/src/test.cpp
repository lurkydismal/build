#include "test.hpp"

#include <array>
#include <atomic>
#include <cmath>
#include <concepts>
#include <cstdio>
#include <cstdlib>
#include <functional>
#include <iostream>
#include <limits>
#include <ranges>
#include <string>
#include <string_view>
#include <thread>
#include <utility>
#include <variant>
#include <vector>

#include "stdfunc.hpp"

namespace {

auto g_array1 =
    stdfunc::makeVariantContainer< std::array >( true,
                                                 std::string_view( " true " ),
                                                 123,
                                                 "",
                                                 'a' );
auto g_array2 =
    stdfunc::makeVariantContainer< std::array >( false,
                                                 std::string_view( " false " ),
                                                 321,
                                                 " ",
                                                 'b' );

} // namespace

TEST( test, EXPECT_TRUE ) {
    EXPECT_TRUE( true );
    EXPECT_TRUE( 1 );
    EXPECT_TRUE( !0 );
    EXPECT_TRUE( "" );
}

TEST( test, EXPECT_FALSE ) {
    EXPECT_FALSE( false );
    EXPECT_FALSE( 0 );
    EXPECT_FALSE( !1 );
    EXPECT_FALSE( nullptr );
}

TEST( test, EXPECT_EQ ) {
    for ( const auto& _element : g_array1 ) {
        _element.visit( []( auto&& _value ) constexpr -> void {
            EXPECT_EQ( _value, _value );
        } );
    }
}

TEST( test, EXPECT_NE ) {
    for ( const auto& [ _element1, _element2 ] :
          std::views::zip( g_array1, g_array2 ) ) {
        std::visit(
            []< typename T1, typename T2 >( T1& _value1,
                                            T2& _value2 ) constexpr -> void {
                if constexpr ( std::equality_comparable_with< T1, T2 > ) {
                    EXPECT_NE( _value1, _value2 );
                }
            },
            _element1, _element2 );
    }
}

// Basic assertions
TEST( test, BasicAssertions$TrueFalseAndNull ) {
    EXPECT_TRUE( true );
    EXPECT_FALSE( false );

    // non-zero integral is true
    EXPECT_TRUE( 1 );
    EXPECT_FALSE( 0 );

    // pointer checks
    int l_x = 5;
    int* l_p = &l_x;
    EXPECT_NE( nullptr, l_p );
    EXPECT_EQ( nullptr, nullptr );
}

TEST( test, ComparisonAssertions$EqualityAndOrdering ) {
    EXPECT_EQ( 5, 2 + 3 );
    EXPECT_NE( 5, 2 + 2 );
    EXPECT_LT( 1, 2 );
    EXPECT_LE( 2, 2 );
    EXPECT_GT( 3, 2 );
    EXPECT_GE( 3, 3 );
}

TEST( test, StringAssertions$CStyleAndStdString ) {
    const char* l_s1 = "hello";
    const char* l_s2 = "hello";
    std::string l_ss = "hello world";

    EXPECT_STREQ( l_s1, l_s2 ); // C strings
    EXPECT_STRNE( l_s1, "goodbye" );
#if 0
    EXPECT_PRED_FORMAT2(PrintToStringPredicateFormat<std::string, std::string>,
                        ss.substr(0,5), "hello"); // demonstrate predicate format use (not typical)
#endif
    EXPECT_THAT( l_ss, HasSubstr( "world" ) ); // needs gmock
}

TEST( test, FloatingAssertions$NearAndNan ) {
    double l_a = 0.1 + 0.2;
    // approximate comparison
    EXPECT_NEAR( l_a, 0.3, 1e-12 );

    double l_nan = std::numeric_limits< double >::quiet_NaN();
    EXPECT_TRUE( std::isnan( l_nan ) );
}

// Fatal vs Non-Fatal demonstration
TEST( test, FatalNonFatal$ExpectVsAssert ) {
#if 0
    EXPECT_EQ( 1, 2 ) << "This EXPECT fails but test continues";
#endif
    // Next line is an example of ASSERT which would abort test body if failed
    ASSERT_EQ( 2, 2 ) << "This ASSERT succeeds and allows continuation";
    SUCCEED() << "Reached after ASSERT";
}

// Capture stdout/stderr
TEST( test, CaptureStdout$CaptureAndCheck ) {
    internal::CaptureStdout();
    std::cout << "hello capture";
    std::string l_output = internal::GetCapturedStdout();
    EXPECT_THAT( l_output, HasSubstr( "hello capture" ) );
}

// Test fixture with SetUp/TearDown + TestSuite SetUp/TearDown
class FixtureExample : public Test {
protected:
    static inline std::vector< int > g_sShared;

    static void SetUpTestSuite() {
        // called once before all tests in this suite
        g_sShared = { 1, 2, 3 };
    }
    static void TearDownTestSuite() { g_sShared.clear(); }

    void SetUp() override {
        // called before each test
        l_local = 100;
    }
    void TearDown() override {
        // called after each test
    }

public:
    int l_local = 0;
};

TEST_F( FixtureExample, UsesLocalAndShared ) {
    EXPECT_EQ( l_local, 100 );
    EXPECT_THAT( g_sShared, ElementsAre( 1, 2, 3 ) );
}

TEST_F( FixtureExample, ModifyShared ) {
    g_sShared.push_back( 4 );
    EXPECT_THAT( g_sShared, ElementsAre( 1, 2, 3, 4 ) );
}

// Parameterized tests (value-parameterized)
class ParamTest : public TestWithParam< int > {};

TEST_P( ParamTest, IsPositive ) {
    int l_v = GetParam();
    EXPECT_GT( l_v, 0 );
}

INSTANTIATE_TEST_SUITE_P( PositiveInts, ParamTest, Values( 1, 2, 3, 10 ) );

// Parameterized test with tuple (multiple params)
class PairParamTest : public TestWithParam< std::pair< int, int > > {};

TEST_P( PairParamTest, SumMatches ) {
    auto [ a, b ] = GetParam();
    EXPECT_EQ( a + b, std::plus<>()( a, b ) );
}

INSTANTIATE_TEST_SUITE_P( Pairs,
                          PairParamTest,
                          Values( std::make_pair( 1, 2 ),
                                  std::make_pair( 3, 4 ),
                                  std::make_pair( 5, 5 ) ) );

// Typed tests
template < typename T >
class TypedExample : public Test {
public:
    using type_t = T;
};

using myTypes_t = Types< int, double, std::string >;
TYPED_TEST_SUITE( TypedExample, myTypes_t );

TYPED_TEST( TypedExample, IsDefaultConstructible ) {
    [[maybe_unused]] TypeParam l_v{};
    SUCCEED();
}

// Matchers examples (requires gmock)
TEST( test, Matchering$ContainerAndStringMatchers ) {
    std::vector< int > l_v{ 1, 2, 3 };
    EXPECT_THAT( l_v, ElementsAre( 1, 2, 3 ) );
    EXPECT_THAT( l_v, Each( Gt( 0 ) ) );
    EXPECT_THAT( l_v, SizeIs( 3u ) );

    std::string l_s = "abc def ghi";
    EXPECT_THAT( l_s, HasSubstr( "def" ) );
    EXPECT_THAT( l_s, MatchesRegex( ".*def.*" ) );
}

TEST( test, Matchering$UnorderedAndContains ) {
    std::vector< int > l_v{ 3, 1, 2 };
    EXPECT_THAT( l_v, UnorderedElementsAre( 1, 2, 3 ) );
    EXPECT_THAT( l_v, Contains( 2 ) );
}

// SCOPED_TRACE and failure context
TEST( test, Tracing$ScopedTraceMakesMessagesClearer ) {
    for ( int l_i = 0; l_i < 3; ++l_i ) {
        SCOPED_TRACE( Message() << "iteration=" << l_i );
        EXPECT_LT( l_i, 5 ); // all pass but if they fail the trace helps
    }
}

// GTEST_SKIP and test properties
TEST( test, SkippingAndProperties$SkipAndRecord ) {
    GTEST_SKIP() << "Skipping because example";
    // RecordProperty is useful for integration with CI/test-reporters
    RecordProperty( "reason", "example skip" );
    FAIL() << "This won't run because test was skipped";
}

// Multithreaded-ish test: user-spawned threads that gtest doesn't manage
TEST( test, UserThreads$WorkerThreadsDoWork ) {
    std::atomic< int > l_counter{ 0 };
    std::vector< std::thread > l_threads;
    l_threads.reserve( 4 );
    for ( int l_i = 0; l_i < 4; ++l_i ) {
        l_threads.emplace_back( [ &l_counter ]() -> void {
            for ( int l_k = 0; l_k < 1000; ++l_k )
                ++l_counter;
        } );
    }
    for ( auto& l_t : l_threads )
        l_t.join();
    EXPECT_EQ( l_counter.load(), 4000 );
}

// Death tests & exit tests (guarded). Requires gtest to support death tests.
#if GTEST_HAS_DEATH_TEST

void willAbort() {
    std::fflush( nullptr );
    abort(); // triggers SIGABRT
}

TEST( test, DeathTests$EXPECT_DEATH_Abort ) {
    // regex ".*" matches any output
    EXPECT_DEATH( willAbort(), ".*" );
}

void willExitCode( int _code ) {
    std::exit( _code );
}

TEST( test, DeathTests$EXPECT_EXIT_Code42 ) {
    // ExitedWithCode matcher checks exit status
    EXPECT_EXIT( willExitCode( 42 ), ExitedWithCode( 42 ), ".*" );
}

// EXPECT_EXIT with function object capturing output
void printsAndExits() {
    std::cerr << "bye world\n";
    std::exit( 3 );
}

TEST( test, ExitTests$PrintsAndExits ) {
    EXPECT_EXIT( printsAndExits(), ExitedWithCode( 3 ),
                 HasSubstr( "bye world" ) );
}

#else

#pragma message( \
    "GTEST_HAS_DEATH_TEST not defined: death tests will be skipped" )

#endif // GTEST_HAS_DEATH_TEST

// Additional helpers/assertions demonstration
#if 0
TEST( test, Additional$SucceedFailAddFailure ) {
    SUCCEED() << "explicit success marker";
    ADD_FAILURE() << "explicit failure marker (non-fatal)";
    // Because ADD_FAILURE is non-fatal, the test continues and ends as failed.
    // For demonstration purposes we assert a condition to pass:
    EXPECT_TRUE( true );
}
#endif
