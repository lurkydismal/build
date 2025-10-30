#include <print>

#include "stdcolor.hpp"
#include "stdfunc.hpp"

namespace {

CONSTRUCTOR void load() {
    std::println( ">>> {}Loaded{}", stdfunc::color::g_green,
                  stdfunc::color::g_reset );
}

DESTRUCTOR void unload() {
    std::println( "<<< {}Unloaded{}", stdfunc::color::g_red,
                  stdfunc::color::g_reset );
}

} // namespace
