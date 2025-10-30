#!/bin/bash
export MY_TEMP_FILE="${MY_TEMP_FILE:-$(mktemp)}"

SCRIPT_DIRECTORY=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )

BUILD_DIRECTORY_NAME='out'

BUILD_DIRECTORY="$SCRIPT_DIRECTORY/$BUILD_DIRECTORY_NAME"

EXECUTABLE_NAME="main.out"
EXECUTABLE_NAME_TESTS="$EXECUTABLE_NAME"'_test'

{

COVERAGE_DIRECTORY_NAME='coverage_html'

llvm-profdata merge \
    -compress-all-sections \
    -sparse 'default.profraw' \
    -o "$MY_TEMP_FILE" && \
llvm-cov show "$BUILD_DIRECTORY/$EXECUTABLE_NAME_TESTS" \
    -show-branches='percent' \
    -instr-profile="$MY_TEMP_FILE" \
    -format='html' \
    -output-dir="$COVERAGE_DIRECTORY_NAME"

}
