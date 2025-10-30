#include "example.hpp"

#include <string_view>

#include "logg.hpp"

namespace example {

void printBuildType() {
    logg$debug( "Message that is only in {}", "Debug" );

#if ( defined( DEBUG ) && !defined( TESTS ) )

    const std::string_view l_buildType = "DEBUG";

#elif defined( RELEASE )

    const std::string_view l_buildType = "RELEASE";

#elif defined( PROFILE )

    const std::string_view l_buildType = "PROFILE";

#elif defined( TESTS )

    const std::string_view l_buildType = "TESTS";

#endif

    logg$variable( l_buildType );

    logg::info( "Build Type: {}", l_buildType );

    logg::warning( "Why not to try another {}?", "build type" );

#if defined( HOT_RELOAD )

    logg::warning( "Hot reload is enabled" );

#endif
}

} // namespace example
