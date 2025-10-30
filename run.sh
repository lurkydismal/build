#!/bin/bash
set -e

export SCRIPT_DIRECTORY=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
export BUILD_DIRECTORY_NAME='out'
export BUILD_DIRECTORY="$SCRIPT_DIRECTORY/$BUILD_DIRECTORY_NAME"

export ASAN_SYMBOLIZER_PATH=
export UBSAN_SYMBOLIZER_PATH= 
# export ASAN_OPTIONS='verbosity=1'
export LSAN_OPTIONS='suppressions='"$SCRIPT_DIRECTORY/"'lsan.suppress' \
    # ':verbosity=2:log_threads=1'
export EXECUTABLE_NAME="main.out""$1"
export EXECUTABLE="$BUILD_DIRECTORY/$EXECUTABLE_NAME"

clear

"$EXECUTABLE" 2>&1 | stdbuf -oL awk -v executable="$EXECUTABLE" -v path="$SCRIPT_DIRECTORY/" '
/\(BuildId:/ {
match( $0, /\+0x([0-9a-fA-F]+)/, matches )

cmd = "llvm-symbolizer -e " executable " <<< " "0x"matches[ 1 ]

sub( path, "", $0 )

sub( / \(BuildId:[^)]*\)/, "", $0 )

first = 0

while ( cmd | getline symbolized ) {
    if ( length( symbolized ) ) {
        sub( path, "", symbolized )

        if (first == 0) {
            print $0 "  ==>  " symbolized
        } else {
            printf "%*s  ==>  %s\n", length( $0 ), "", symbolized
        }

        first = 1
    }
}

close( cmd )

next
}
{
    # TODO: Color line if ERROR
    sub( path, "", symbolized )

    print $0
}
'
