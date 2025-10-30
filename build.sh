#!/bin/bash
shopt -s nullglob

export RED_LIGHT_COLOR='\e[1;31m'
export GREEN_LIGHT_COLOR='\e[1;32m'
export YELLOW_COLOR='\e[1;33m'
export BLUE_LIGHT_COLOR='\e[1;34m'
export PURPLE_LIGHT_COLOR='\e[1;35m'
export CYAN_LIGHT_COLOR='\e[1;36m'
export RESET_COLOR='\e[0m'

export FAIL_COLOR="$RED_LIGHT_COLOR"

# Helper functions
exit_failure() {
    local message="${1:-}"

    [[ $message ]] && echo -e "$FAIL_COLOR""$message""$RESET_COLOR"

    # trap 'echo "Line $LINENO: $BASH_COMMAND";echo; exit 1' ERR

    exit 1
}

exit_success() {
    exit 0
}

export -f exit_failure exit_success

export SCRIPT_DIRECTORY
SCRIPT_DIRECTORY=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)
export BUILD_DIRECTORY_NAME="out"
export TESTS_DIRECTORY_NAME="tests"
export BUILD_DIRECTORY="$SCRIPT_DIRECTORY/$BUILD_DIRECTORY_NAME"
export TESTS_DIRECTORY="$TESTS_DIRECTORY_NAME"

export HASH_FUNCTION="sha512sum"

declare -A BUILD_TYPES=(
    [DEBUG]=0
    [RELEASE]=1
    [PROFILE]=2
    [TESTS]=3
)

BUILD_TYPE_NAME="${BUILD_TYPE_NAME:-DEBUG}"

if [[ -z "${BUILD_TYPES[$BUILD_TYPE_NAME]+_}" ]]; then
    exit_failure "Unknown BUILD_TYPE_NAME '$BUILD_TYPE_NAME'"
fi

export BUILD_TYPE="${BUILD_TYPE:-${BUILD_TYPES[$BUILD_TYPE_NAME]}}"

# Handle command line arguments
{
    function show_version {
        echo "${0##*/} 0.0"
    }

    function show_help {
        cat <<EOF
Usage: $0 [OPTION...]
Modular Bash build system: configure modules in config.sh to build each module with make (parallel), supports Debug/ Release/ Profile/ Tests modes, ccache/ pkg-config, and optional hot-reload (make modules into shared objects).

  -v     Print version
  -h     Show this help message
  -d     Build debug
  -r     Build release
  -p     Build profile
  -t     Build tests
  -o     Disable optimizations
  -s     Enable sanitizers
  -b     Scan build
  -e     Enable hot reload
  -i     Strip executable
  -c     Disable build cache
  -a     Rebuild static parts
  -u     Rebuild parts

Mandatory or optional arguments to long options are also mandatory or optional
for any corresponding short options.
    
Report bugs to <lurkydismal@duck.com>.
EOF
    }

    while getopts "vhdrptosbeicau" _option; do
        case $_option in
        v)
            show_version
            exit_success
            ;;
        h)
            show_help
            exit_success
            ;;
        d) BUILD_TYPE=${BUILD_TYPES[DEBUG]} ;;
        r) BUILD_TYPE=${BUILD_TYPES[RELEASE]} ;;
        p) BUILD_TYPE=${BUILD_TYPES[PROFILE]} ;;
        t) BUILD_TYPE=${BUILD_TYPES[TESTS]} ;;
        o) DISABLE_OPTIMIZATIONS= ;;
        s) ENABLE_SANITIZERS= ;;
        b) SCAN_BUILD= ;;
        e) ENABLE_HOT_RELOAD= ;;
        i) STRIP_EXECUTABLE= ;;
        c) DISABLE_BUILD_CACHE= ;;
        a) REBUILD_STATIC_PARTS= ;;
        u) REBUILD_PARTS= ;;
        *) exit_failure ;;
        esac
    done
}

export BUILD_C_FLAGS="-pipe -std=gnu23 -march=native -ffunction-sections -fdata-sections -fPIC -fopenmp-simd -fno-ident -fno-short-enums -Wall -Wextra -Wno-gcc-compat -Wno-incompatible-pointer-types-discards-qualifiers"
export BUILD_C_FLAGS_DEBUG="-Og -ggdb3"
export BUILD_C_FLAGS_RELEASE="-flto=jobserver -fprofile-instr-use -O3 -ffast-math -funroll-loops -fno-asynchronous-unwind-tables"
export BUILD_C_FLAGS_PROFILE="-fprofile-instr-generate -pg -O3 -ffast-math -funroll-loops -fno-asynchronous-unwind-tables"
export BUILD_C_FLAGS_TESTS="$BUILD_C_FLAGS_DEBUG -fopenmp -O0"
export BUILD_C_FLAGS_HOT_RELOAD=""

export BUILD_CPP_FLAGS="$BUILD_C_FLAGS -std=gnu++26 -fno-rtti -fno-exceptions -fno-threadsafe-statics -Wno-enum-enum-conversion -Wno-c99-designator -Wno-gnu-string-literal-operator-template"
export BUILD_CPP_FLAGS_DEBUG="$BUILD_C_FLAGS_DEBUG"
export BUILD_CPP_FLAGS_RELEASE="$BUILD_C_FLAGS_RELEASE -fno-unwind-tables"
export BUILD_CPP_FLAGS_PROFILE="$BUILD_C_FLAGS_PROFILE -fno-unwind-tables"
export BUILD_CPP_FLAGS_TESTS="$BUILD_C_FLAGS_TESTS"
export BUILD_CPP_FLAGS_HOT_RELOAD=""

# TODO: checker alpha
export SCAN_BUILD_FLAGS="-enable-checker core,security,nullability,deadcode,unix,optin"

export BUILD_DEFINES=(
    "_GNU_SOURCE"
)

export BUILD_DEFINES_DEBUG=(
    "DEBUG"
    "LOG_WATCH"
)

export BUILD_DEFINES_RELEASE=(
    "RELEASE"
)

export BUILD_DEFINES_PROFILE=(
    "PROFILE"
)

export BUILD_DEFINES_TESTS=(
    "${BUILD_DEFINES_DEBUG[@]}"
    "TESTS"
)

export BUILD_DEFINES_HOT_RELOAD=(
    "HOT_RELOAD"
)

export BUILD_INCLUDES=()

export LINK_FLAGS="-fPIC -fuse-ld=mold -Wl,-O1 -Wl,--gc-sections"
export LINK_FLAGS_DEBUG="-rdynamic"
export LINK_FLAGS_RELEASE="-flto -s -Wl,--no-eh-frame-hdr"
export LINK_FLAGS_PROFILE="-Wl,--no-eh-frame-hdr"
export LINK_FLAGS_TESTS="-fopenmp $LINK_FLAGS_DEBUG"
export LINK_FLAGS_HOT_RELOAD="-Wl,-rpath,\$ORIGIN"

export LIBRARIES_TO_LINK=()
export LIBRARIES_TO_LINK_TESTS=()
export EXTERNAL_LIBRARIES_TO_LINK=()
export EXTERNAL_LIBRARIES_TO_LINK_TESTS=()
export C_COMPILER="clang"
export CPP_COMPILER="clang++"

export EXECUTABLE_NAME="main.out"
export EXECUTABLE_NAME_TESTS="$EXECUTABLE_NAME"'_test'
export EXECUTABLE_SECTIONS_TO_STRIP=(
    ".note.gnu.build-id"
    ".note.gnu.property"
    ".comment"
    ".eh_frame"
    ".eh_frame_hdr"
    ".relro_padding"
)

# Helper functions
check_availability() {
    local what=$1

    command -v $what >/dev/null 2>&1 || {
        exit_failure "$what"' not found'
    }
}

# TODO: Better name
array_to_string() {
    local output_variable="$1"
    local -n array_reference="$2"
    local prefix="$3"
    local color="$4"
    local postfix="${5:-}"
    # TODO: Better name
    local root_directory="${6:-$BUILD_DIRECTORY}/"

    printf -v "$output_variable" -- "$prefix$root_directory%s$postfix " "${array_reference[@]}"
    echo -en "$color"
    printf -- "$prefix%s$postfix " "${array_reference[@]}"
    echo -e "$RESET_COLOR"
}

clear

cd "$SCRIPT_DIRECTORY" || exit

source './config.sh' && {

    check_availability 'fd'

    mkdir -p "$BUILD_DIRECTORY"

    # Remove all object files
    {
        # Release
        if [ "$BUILD_TYPE" -eq "${BUILD_TYPES[RELEASE]}" ]; then
            fd -I -e o -x rm {}

        else
            if [ ${#staticParts[@]} -ne 0 ]; then
                printf -v staticPartsAsExcludeString -- "-E %s " "${staticParts[@]}"

            else
                staticPartsAsExcludeString=""
            fi

            fd -I -e o "$staticPartsAsExcludeString" -x rm {}

            unset staticPartsAsExcludeString
        fi
    }

    if [ -n "${DISABLE_OPTIMIZATIONS+x}" ]; then
        BUILD_C_FLAGS_DEBUG+=" -O0"
        BUILD_C_FLAGS_RELEASE+=" -O0"
        BUILD_C_FLAGS_PROFILE+=" -O0"
        BUILD_C_FLAGS_TESTS+=" -O0"

        BUILD_CPP_FLAGS_DEBUG+=" -O0"
        BUILD_CPP_FLAGS_RELEASE+=" -O0"
        BUILD_CPP_FLAGS_PROFILE+=" -O0"
        BUILD_CPP_FLAGS_TESTS+=" -O0"
    fi

    # Clang-specific flags
    {
        BUILD_C_FLAGS+=" -Wno-c23-extensions -Wno-gnu-folding-constant"
        BUILD_CPP_FLAGS+=" -Wno-c23-extensions -Wno-gnu-folding-constant"

        # Debug or Tests
        if [ "$BUILD_TYPE" -eq "${BUILD_TYPES[DEBUG]}" ] || [ "$BUILD_TYPE" -eq "${BUILD_TYPES[TESTS]}" ]; then
            BUILD_C_FLAGS_PROFILE+=" -fprofile-instr-generate -fcoverage-mapping"
            BUILD_C_FLAGS_TESTS+=" -fprofile-instr-generate -fcoverage-mapping"

            BUILD_CPP_FLAGS_PROFILE+=" -fprofile-instr-generate -fcoverage-mapping"
            BUILD_CPP_FLAGS_TESTS+=" -fprofile-instr-generate -fcoverage-mapping"

            LINK_FLAGS_PROFILE+=" -fprofile-instr-generate -fcoverage-mapping"
            LINK_FLAGS_TESTS+=" -fprofile-instr-generate -fcoverage-mapping"
        fi

        if [ -n "${ENABLE_SANITIZERS+x}" ]; then
            BUILD_C_FLAGS_DEBUG+=" -fsanitize=address,undefined,leak"
            BUILD_C_FLAGS_TESTS+=" -fsanitize=address,undefined,leak"

            BUILD_CPP_FLAGS_DEBUG+=" -fsanitize=address,undefined,leak"
            BUILD_CPP_FLAGS_TESTS+=" -fsanitize=address,undefined,leak"

            LINK_FLAGS_DEBUG+=" -fsanitize=address,undefined,leak"
            LINK_FLAGS_TESTS+=" -fsanitize=address,undefined,leak"
        fi
    }

    # Debug
    if [ "$BUILD_TYPE" -eq "${BUILD_TYPES[DEBUG]}" ]; then
        echo -e "$BUILD_TYPE_COLOR"'Debug build'"$RESET_COLOR"

        BUILD_C_FLAGS="$BUILD_C_FLAGS $BUILD_C_FLAGS_DEBUG"
        BUILD_CPP_FLAGS="$BUILD_CPP_FLAGS $BUILD_CPP_FLAGS_DEBUG"
        LINK_FLAGS="$LINK_FLAGS $LINK_FLAGS_DEBUG"
        BUILD_DEFINES+=("${BUILD_DEFINES_DEBUG[@]}")

    # Release
    elif [ "$BUILD_TYPE" -eq "${BUILD_TYPES[RELEASE]}" ]; then
        echo -e "$BUILD_TYPE_COLOR"'Release build'"$RESET_COLOR"

        BUILD_C_FLAGS="$BUILD_C_FLAGS $BUILD_C_FLAGS_RELEASE"
        BUILD_CPP_FLAGS="$BUILD_CPP_FLAGS $BUILD_CPP_FLAGS_RELEASE"
        LINK_FLAGS="$LINK_FLAGS $LINK_FLAGS_RELEASE"
        BUILD_DEFINES+=("${BUILD_DEFINES_RELEASE[@]}")

    # Profile
    elif [ "$BUILD_TYPE" -eq "${BUILD_TYPES[PROFILE]}" ]; then
        echo -e "$BUILD_TYPE_COLOR"'Profile build'"$RESET_COLOR"

        BUILD_C_FLAGS="$BUILD_C_FLAGS $BUILD_C_FLAGS_PROFILE"
        BUILD_CPP_FLAGS="$BUILD_CPP_FLAGS $BUILD_CPP_FLAGS_PROFILE"
        LINK_FLAGS="$LINK_FLAGS $LINK_FLAGS_PROFILE"
        BUILD_DEFINES+=("${BUILD_DEFINES_PROFILE[@]}")

    # Tests
    elif [ "$BUILD_TYPE" -eq "${BUILD_TYPES[TESTS]}" ]; then
        echo -e "$BUILD_TYPE_COLOR"'Building tests'"$RESET_COLOR"

        BUILD_C_FLAGS="$BUILD_C_FLAGS $BUILD_C_FLAGS_TESTS"
        BUILD_CPP_FLAGS="$BUILD_CPP_FLAGS $BUILD_CPP_FLAGS_TESTS"
        LINK_FLAGS="$LINK_FLAGS $LINK_FLAGS_TESTS"
        BUILD_DEFINES+=("${BUILD_DEFINES_TESTS[@]}")
    fi

    # Hot reload
    if [ -n "${ENABLE_HOT_RELOAD+x}" ]; then
        echo -e "$BUILD_TYPE_COLOR"'Building with hot reload'"$RESET_COLOR"

        BUILD_C_FLAGS="$BUILD_C_FLAGS $BUILD_C_FLAGS_HOT_RELOAD"
        BUILD_CPP_FLAGS="$BUILD_CPP_FLAGS $BUILD_CPP_FLAGS_HOT_RELOAD"
        LINK_FLAGS="$LINK_FLAGS $LINK_FLAGS_HOT_RELOAD"
        BUILD_DEFINES+=("${BUILD_DEFINES_HOT_RELOAD[@]}")
    fi

    # Set COMPILER
    # FIX: Do not hard code COMPILER and detect it
    COMPILER="$CPP_COMPILER"

    if [ -z "${DISABLE_BUILD_CACHE+x}" ]; then
        C_COMPILER="ccache $C_COMPILER"
        CPP_COMPILER="ccache $CPP_COMPILER"
    fi

    if [ -n "${SCAN_BUILD+x}" ]; then
        C_COMPILER="scan-build $SCAN_BUILD_FLAGS $C_COMPILER"
        CPP_COMPILER="scan-build $SCAN_BUILD_FLAGS $CPP_COMPILER"
    fi

    check_availability $C_COMPILER
    check_availability $CPP_COMPILER
    check_availability $COMPILER

    if [ ${#BUILD_DEFINES[@]} -ne 0 ]; then
        printf -v definesAsString -- "-D %s " "${BUILD_DEFINES[@]}"
        echo -e "$DEFINES_COLOR""$definesAsString""$RESET_COLOR"
    fi

    # Generate includes
    {
        mapfile -t new_build_includes < <(printf -- "%s/include""\n" "${partsToBuild[@]}" "${staticParts[@]}")

        BUILD_INCLUDES+=("${new_build_includes[@]}")

        BUILD_INCLUDES+=("$testsMainPackage"'/include')

        if [ ${#BUILD_INCLUDES[@]} -ne 0 ]; then
            printf -v includesAsString -- "-I $SCRIPT_DIRECTORY/%s " "${BUILD_INCLUDES[@]}"
            echo -en "$INCLUDES_COLOR"
            printf -- "-I %s " "${BUILD_INCLUDES[@]}"
            echo -e "$RESET_COLOR"
        fi
    }

    if [ ${#EXTERNAL_LIBRARIES_TO_LINK[@]} -ne 0 ]; then
        printf -v externalLibrariesAsString -- "%s " "${EXTERNAL_LIBRARIES_TO_LINK[@]}"

        echo -e '\n'"$EXTERNAL_LIBRARIES_COLOR""$externalLibrariesAsString""$RESET_COLOR"
        externalLibrariesBuildFlagsAsString="$(pkg-config --static --cflags "$externalLibrariesAsString")"' '

        SEARCH_STATUS=$?

        if [ $SEARCH_STATUS -ne 0 ]; then
            exit $SEARCH_STATUS
        fi

        echo -e "$INCLUDES_COLOR""$externalLibrariesBuildFlagsAsString""$RESET_COLOR"
        externalLibrariesLinkFlagsAsString="$(pkg-config --static --libs "$externalLibrariesAsString")"' '

        SEARCH_STATUS=$?

        if [ $SEARCH_STATUS -ne 0 ]; then
            exit $SEARCH_STATUS
        fi

        echo -e "$LIBRARIES_COLOR""$externalLibrariesLinkFlagsAsString""$RESET_COLOR"

        unset externalLibrariesAsString
    fi

    processedFiles=()
    processedFilesStatic=()
    declare -A processedFilesHashes=()
    processIDs=()
    processStatuses=()
    BUILD_STATUS=0

    if [ ${#partsToBuild[@]} -ne 0 ]; then
        printf -v partsToBuildAsString -- "$BUILD_DIRECTORY/lib%s"'.a ' "${partsToBuild[@]}"
        echo -en "$PARTS_TO_BUILD_COLOR"
        printf -- "lib%s"'.a ' "${partsToBuild[@]}"
        echo -e "$RESET_COLOR"
    fi

    for partToBuild in "${partsToBuild[@]}"; do
        export FILES_TO_INCLUDE=""
        export FILES_TO_COMPILE=""

        source "$partToBuild/config.sh" && {
            OUTPUT_FILE='lib'"$partToBuild"'.a'

            processedFiles+=("$OUTPUT_FILE")

            if [ -f "$BUILD_DIRECTORY/$OUTPUT_FILE" ]; then
                processedFilesHashes["$OUTPUT_FILE"]="$($HASH_FUNCTION "$BUILD_DIRECTORY/$OUTPUT_FILE" | cut -d ' ' -f1)"
            fi

            OUTPUT_FILE="$OUTPUT_FILE" \
                './build_module.sh' \
                "$partToBuild" \
                "$BUILD_C_FLAGS $externalLibrariesBuildFlagsAsString" \
                "$BUILD_CPP_FLAGS $externalLibrariesBuildFlagsAsString" \
                "$definesAsString" \
                "$includesAsString" \
                "$([ -n "${REBUILD_PARTS+x}" ] && echo 1 || echo 0)" \
                "module" &

            processIDs+=($!)
        } || exit_failure

        unset FILES_TO_INCLUDE FILES_TO_COMPILE

        BUILD_STATUS=$?

        if [ $BUILD_STATUS -ne 0 ]; then
            exit_failure
        fi
    done

    {
        if [ ${#staticParts[@]} -ne 0 ]; then
            printf -v staticPartsAsString -- "$BUILD_DIRECTORY/lib%s.a " "${staticParts[@]}"
            echo -en "$PARTS_TO_BUILD_COLOR"
            printf -- "lib%s"'.a ' "${staticParts[@]}"
            echo -e "$RESET_COLOR"
        fi

        for staticPart in "${staticParts[@]}"; do
            export FILES_TO_INCLUDE=""
            export FILES_TO_COMPILE=""

            source "$staticPart/config.sh" && {
                OUTPUT_FILE='lib'"$staticPart"'.a'

                processedFilesStatic+=("$OUTPUT_FILE")

                if [ -f "$BUILD_DIRECTORY/$OUTPUT_FILE" ]; then
                    processedFilesHashes["$OUTPUT_FILE"]="$($HASH_FUNCTION "$BUILD_DIRECTORY/$OUTPUT_FILE" | cut -d ' ' -f1)"
                fi

                if [ -z "${REBUILD_STATIC_PARTS+x}" ]; then
                    if [ -f "$BUILD_DIRECTORY/$OUTPUT_FILE" ]; then
                        printf -- "%bSkipping static '%-${MODULE_NAME_FIELD_WIDTH}s — '%s' already exists.%b\n" "$SKIPPING_PART_IN_BUILD_COLOR" "$staticPart'" "$OUTPUT_FILE" "$RESET_COLOR"

                        continue
                    fi
                fi

                OUTPUT_FILE="$OUTPUT_FILE" \
                    './build_module.sh' \
                    "$staticPart" \
                    "$BUILD_C_FLAGS $externalLibrariesBuildFlagsAsString" \
                    "$BUILD_CPP_FLAGS $externalLibrariesBuildFlagsAsString" \
                    "$definesAsString" \
                    "$includesAsString" \
                    "$([ -n "${REBUILD_STATIC_PARTS+x}" ] && echo 1 || echo 0)" \
                    "static" &

                processIDs+=($!)
            } || exit_failure

            unset FILES_TO_INCLUDE FILES_TO_COMPILE

            BUILD_STATUS=$?

            if [ $BUILD_STATUS -ne 0 ]; then
                exit_failure
            fi
        done
    }

    for processID in "${processIDs[@]}"; do
        wait "$processID"

        processStatuses+=($?)
    done

    BUILD_STATUS=0

    for processStatus in "${processStatuses[@]}"; do
        if [[ "$processStatus" -ne 0 ]]; then
            BUILD_STATUS=$processStatus

            break
        fi
    done

    processIDs=()
    processStatuses=()

    if [ "$BUILD_STATUS" -ne 0 ]; then
        exit_failure
    fi

    # Debug
    if [ "$BUILD_TYPE" -eq "${BUILD_TYPES[DEBUG]}" ] && [ -n "${ENABLE_HOT_RELOAD+x}" ]; then
        # Convert static to shared objects
        for processedFile in "${processedFilesStatic[@]}"; do
            outputFile="${processedFile%.a}.so"

            if [ -z "${REBUILD_STATIC_PARTS+x}" ]; then
                if [ -f "$BUILD_DIRECTORY/$outputFile" ]; then
                    continue
                fi
            fi

            if [ ! -f "$BUILD_DIRECTORY/$outputFile" ] || [ "$($HASH_FUNCTION "$BUILD_DIRECTORY/$processedFile" | cut -d ' ' -f1)" != "${processedFilesHashes["$processedFile"]}" ]; then
                echo "Linking static $outputFile"

                $COMPILER -shared -nostdlib $LINK_FLAGS '-Wl,--whole-archive' "$BUILD_DIRECTORY/$processedFile" '-Wl,--no-whole-archive' -o "$BUILD_DIRECTORY/""$outputFile" &

                export NEED_HOT_RELOAD

                processIDs+=($!)
            fi
        done

        for processID in "${processIDs[@]}"; do
            wait "$processID"

            processStatuses+=($?)
        done

        BUILD_STATUS=0

        for processStatus in "${processStatuses[@]}"; do
            if [[ "$processStatus" -ne 0 ]]; then
                BUILD_STATUS=$processStatus

                break
            fi
        done

        if [ "$BUILD_STATUS" -ne 0 ]; then
            exit_failure
        fi

        processIDs=()
        processStatuses=()

        # Convert to shared objects
        for processedFile in "${processedFiles[@]}"; do
            outputFile="${processedFile%.a}.so"

            if [ ! -f "$BUILD_DIRECTORY/$outputFile" ] || [ "$($HASH_FUNCTION "$BUILD_DIRECTORY/$processedFile" | cut -d ' ' -f1)" != "${processedFilesHashes["$processedFile"]}" ]; then
                echo "Linking $outputFile"

                cd "$BUILD_DIRECTORY" || exit_failure

                $COMPILER -shared -nostdlib $LINK_FLAGS '-Wl,--whole-archive' "$BUILD_DIRECTORY/$processedFile" '-Wl,--no-whole-archive' -o "$BUILD_DIRECTORY/""$outputFile" &

                cd - >'/dev/null' || exit_failure

                export NEED_HOT_RELOAD

                processIDs+=($!)
            fi
        done

        for processID in "${processIDs[@]}"; do
            wait "$processID"

            processStatuses+=($?)
        done

        BUILD_STATUS=0

        for processStatus in "${processStatuses[@]}"; do
            if [[ "$processStatus" -ne 0 ]]; then
                BUILD_STATUS=$processStatus

                break
            fi
        done

        if [ "$BUILD_STATUS" -ne 0 ]; then
            exit_failure
        fi

        processIDs=()
        processStatuses=()

        if [ -z "${NEED_HOT_RELOAD+x}" ]; then
            # Link root that will have DT_NEEDED for all shared objects
            source "$rootSharedObjectName/config.sh" && {
                OUTPUT_FILE="$rootSharedObjectName"'.a'

                OUTPUT_FILE="$OUTPUT_FILE" \
                    './build_module.sh' \
                    "$rootSharedObjectName" \
                    "$BUILD_C_FLAGS" \
                    "$BUILD_CPP_FLAGS" \
                    "$definesAsString" \
                    "$includesAsString" \
                    "$([ -n "${REBUILD_PARTS+x}" ] && echo 1 || echo 0)" \
                    "module"

                outputFile="$rootSharedObjectName"'.so'

                echo "Linking $outputFile"

                cd "$BUILD_DIRECTORY" || exit_failure

                $COMPILER -shared $LINK_FLAGS '-Wl,--whole-archive' "$BUILD_DIRECTORY/$OUTPUT_FILE" '-Wl,--no-whole-archive' ${processedFiles[@]/%.a/.so} -o "$BUILD_DIRECTORY/$outputFile"

                BUILD_STATUS=$?

                cd - >'/dev/null' || exit_failure

                if [ $BUILD_STATUS -ne 0 ]; then
                    exit_failure
                fi
            } || exit_failure
        fi

        BUILD_STATUS=$?

        if [ $BUILD_STATUS -ne 0 ]; then
            exit_failure
        fi
    fi

    unset processedFilesHashes

    # Build main executable
    {
        # Build executable main package
        {
            export FILES_TO_INCLUDE=""
            export FILES_TO_COMPILE=""

            source "$executableMainPackage/config.sh" && {
                OUTPUT_FILE='lib'"$executableMainPackage"'.a'

                OUTPUT_FILE="$OUTPUT_FILE" \
                    './build_module.sh' \
                    "$executableMainPackage" \
                    "$BUILD_C_FLAGS $externalLibrariesBuildFlagsAsString" \
                    "$BUILD_CPP_FLAGS $externalLibrariesBuildFlagsAsString" \
                    "$definesAsString" \
                    "$includesAsString" \
                    "$([ -n "${REBUILD_PARTS+x}" ] && echo 1 || echo 0)" \
                    "module"

                BUILD_STATUS=$?

                if [ $BUILD_STATUS -ne 0 ]; then
                    exit_failure
                fi
            } || exit_failure

            unset FILES_TO_INCLUDE FILES_TO_COMPILE

            BUILD_STATUS=$?

            if [ $BUILD_STATUS -ne 0 ]; then
                exit_failure
            fi
        }

        if [ ${#LIBRARIES_TO_LINK[@]} -ne 0 ]; then
            printf -v librariesToLinkAsString -- "-l%s " "${LIBRARIES_TO_LINK[@]}"
            echo -e "$LIBRARIES_COLOR""$librariesToLinkAsString""$RESET_COLOR"
        fi

        # Not Tests
        if [ "$BUILD_TYPE" -ne "${BUILD_TYPES[TESTS]}" ]; then
            if [ -z "${SCAN_BUILD+x}" ]; then
                # Debug
                if [ "$BUILD_TYPE" -eq "${BUILD_TYPES[DEBUG]}" ] && [ -n "${ENABLE_HOT_RELOAD+x}" ]; then
                    cd "$BUILD_DIRECTORY" || exit_failure

                    $COMPILER $LINK_FLAGS "$BUILD_DIRECTORY/"'lib'"$executableMainPackage"'.a' ${processedFilesStatic[@]/%.a/.so} ${processedFiles[@]/%.a/.so} $librariesToLinkAsString $externalLibrariesLinkFlagsAsString -o "$BUILD_DIRECTORY/$EXECUTABLE_NAME"

                    BUILD_STATUS=$?

                    cd - >'/dev/null' || exit_failure

                else
                    $COMPILER $LINK_FLAGS "$BUILD_DIRECTORY/"'lib'"$executableMainPackage"'.a' $staticPartsAsString $partsToBuildAsString $librariesToLinkAsString $externalLibrariesLinkFlagsAsString -o "$BUILD_DIRECTORY/$EXECUTABLE_NAME"

                    BUILD_STATUS=$?
                fi

                if [ $BUILD_STATUS -ne 0 ]; then
                    exit_failure
                fi

                echo -e "$BUILT_EXECUTABLE_COLOR""$EXECUTABLE_NAME""$RESET_COLOR"
            fi

            if [ -n "${STRIP_EXECUTABLE+x}" ]; then
                if [ ${#EXECUTABLE_SECTIONS_TO_STRIP[@]} -ne 0 ]; then
                    printf -v sectionsToStripAsString -- "--remove-section %s " "${EXECUTABLE_SECTIONS_TO_STRIP[@]}"
                    echo -e "$SECTIONS_TO_STRIP_COLOR""$sectionsToStripAsString""$RESET_COLOR"
                fi

                objcopy "$BUILD_DIRECTORY/$EXECUTABLE_NAME" $sectionsToStripAsString

                strip --strip-section-headers "$BUILD_DIRECTORY/$EXECUTABLE_NAME"
            fi
        fi
    }

    # Build tests
    if [ "$BUILD_TYPE" -eq "${BUILD_TYPES[TESTS]}" ]; then
        if [ ${#EXTERNAL_LIBRARIES_TO_LINK_TESTS[@]} -ne 0 ]; then
            printf -v externalLibrariesTestsAsString -- "%s " "${EXTERNAL_LIBRARIES_TO_LINK_TESTS[@]}"

            echo -e '\n'"$EXTERNAL_LIBRARIES_COLOR""$externalLibrariesTestsAsString""$RESET_COLOR"
            externalLibrariesTestsBuildFlagsAsString="$(pkg-config --static --cflags "$externalLibrariesTestsAsString")"' '

            SEARCH_STATUS=$?

            if [ $SEARCH_STATUS -ne 0 ]; then
                exit $SEARCH_STATUS
            fi

            echo -e "$INCLUDES_COLOR""$externalLibrariesTestsBuildFlagsAsString""$RESET_COLOR"
            externalLibrariesTestsLinkFlagsAsString="$(pkg-config --static --libs "$externalLibrariesTestsAsString")"' '

            SEARCH_STATUS=$?

            if [ $SEARCH_STATUS -ne 0 ]; then
                exit $SEARCH_STATUS
            fi

            echo -e "$LIBRARIES_COLOR""$externalLibrariesTestsLinkFlagsAsString""$RESET_COLOR"

            unset externalLibrariesTestsAsString
        fi

        for testToBuild in "${testsToBuild[@]}"; do
            export FILES_TO_INCLUDE=""
            export FILES_TO_COMPILE=""

            source "$testToBuild/$TESTS_DIRECTORY/config.sh" && {
                OUTPUT_FILE='lib'"$testToBuild"'_test.a'

                OUTPUT_FILE="$OUTPUT_FILE" \
                    './build_module.sh' \
                    "$testToBuild/$TESTS_DIRECTORY" \
                    "$BUILD_C_FLAGS $externalLibrariesBuildFlagsAsString $externalLibrariesTestsBuildFlagsAsString" \
                    "$BUILD_CPP_FLAGS $externalLibrariesBuildFlagsAsString $externalLibrariesTestsBuildFlagsAsString" \
                    "$definesAsString" \
                    "$includesAsString" \
                    "$([ -n "${REBUILD_PARTS+x}" ] && echo 1 || echo 0)" \
                    "module" &

                processIDs+=($!)
            } || exit_failure

            unset FILES_TO_INCLUDE FILES_TO_COMPILE

            BUILD_STATUS=$?

            if [ $BUILD_STATUS -ne 0 ]; then
                exit_failure
            fi
        done

        for processID in "${processIDs[@]}"; do
            wait "$processID"

            processStatuses+=($?)
        done

        BUILD_STATUS=0

        for processStatus in "${processStatuses[@]}"; do
            if [[ "$processStatus" -ne 0 ]]; then
                BUILD_STATUS=$processStatus

                break
            fi
        done

        if [ "$BUILD_STATUS" -ne 0 ]; then
            exit_failure
        fi

        processIDs=()
        processStatuses=()

        # Build tests main package
        {
            export FILES_TO_INCLUDE=""
            export FILES_TO_COMPILE=""

            source "$testsMainPackage/config.sh" && {
                OUTPUT_FILE='lib'"$testsMainPackage"'.a' \
                    './build_module.sh' \
                    "$testsMainPackage" \
                    "$BUILD_C_FLAGS $externalLibrariesBuildFlagsAsString $externalLibrariesTestsBuildFlagsAsString" \
                    "$BUILD_CPP_FLAGS $externalLibrariesBuildFlagsAsString $externalLibrariesTestsBuildFlagsAsString" \
                    "$definesAsString" \
                    "$includesAsString" \
                    "$([ -n "${REBUILD_PARTS+x}" ] && echo 1 || echo 0)" \
                    "module"

                BUILD_STATUS=$?

                if [ $BUILD_STATUS -ne 0 ]; then
                    exit_failure
                fi
            } || exit_failure

            unset FILES_TO_INCLUDE FILES_TO_COMPILE

            BUILD_STATUS=$?

            if [ $BUILD_STATUS -ne 0 ]; then
                exit_failure
            fi
        }

        {
            if [ ${#testsToBuild[@]} -ne 0 ]; then
                printf -v testsToBuildAsString -- "$BUILD_DIRECTORY/lib%s_test.a " "${testsToBuild[@]}"
                echo -en "$PARTS_TO_BUILD_COLOR"
                printf -- "lib%s"'_test.a ' "${testsToBuild[@]}"
                echo -e "$RESET_COLOR"
            fi

            if [ ${#LIBRARIES_TO_LINK_TESTS[@]} -ne 0 ]; then
                printf -v testsLibrariesToLinkAsString -- "-l%s " "${LIBRARIES_TO_LINK_TESTS[@]}"
                echo -e "$LIBRARIES_COLOR""$testsLibrariesToLinkAsString""$RESET_COLOR"
            fi

            if [ -z "${SCAN_BUILD+x}" ]; then
                $COMPILER $LINK_FLAGS '-Wl,--whole-archive' "$BUILD_DIRECTORY/"'lib'"$testsMainPackage"'.a' $testsToBuildAsString $staticPartsAsString $partsToBuildAsString '-Wl,--no-whole-archive' $librariesToLinkAsString $externalLibrariesLinkFlagsAsString $externalLibrariesTestsLinkFlagsAsString $testsLibrariesToLinkAsString -o "$BUILD_DIRECTORY/$EXECUTABLE_NAME_TESTS"

                BUILD_STATUS=$?

                if [ $BUILD_STATUS -ne 0 ]; then
                    exit_failure
                fi

                echo -e "$BUILT_EXECUTABLE_COLOR""$EXECUTABLE_NAME_TESTS""$RESET_COLOR"
            fi

            if [ -n "${STRIP_EXECUTABLE+x}" ]; then
                if [ ${#EXECUTABLE_SECTIONS_TO_STRIP[@]} -ne 0 ]; then
                    printf -v sectionsToStripAsString -- "--remove-section %s " "${EXECUTABLE_SECTIONS_TO_STRIP[@]}"
                    echo -e "$SECTIONS_TO_STRIP_COLOR""$sectionsToStripAsString""$RESET_COLOR"
                fi

                objcopy "$BUILD_DIRECTORY/$EXECUTABLE_NAME_TESTS" $sectionsToStripAsString

                strip --strip-section-headers "$BUILD_DIRECTORY/$EXECUTABLE_NAME_TESTS"
            fi
        }
    fi

} || exit_failure

cd - >'/dev/null' || exit_failure
