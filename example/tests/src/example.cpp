#include "example.hpp"

#include "test.hpp"

TEST( Example, nothing ) {
    ASSERT_TRUE( true );

    example::printBuildType();
}
