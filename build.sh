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
export PROFILE_RAW_FILE="${PROFILE_RAW_FILE:-$SCRIPT_DIRECTORY/default.profraw}"
export PROFILE_DATA_FILE="${PROFILE_DATA_FILE:-$SCRIPT_DIRECTORY/default.profdata}"

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
export BUILD_C_FLAGS_RELEASE="-flto=jobserver -fprofile-instr-use=$PROFILE_DATA_FILE -O3 -ffast-math -funroll-loops -fno-asynchronous-unwind-tables"
export BUILD_C_FLAGS_PROFILE="-fprofile-instr-generate=$PROFILE_RAW_FILE -pg -O3 -ffast-math -funroll-loops -fno-asynchronous-unwind-tables"
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
export LINK_FLAGS_PROFILE="-fprofile-instr-generate=$PROFILE_RAW_FILE -Wl,--no-eh-frame-hdr"
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

prepare_profile_data() {
    if [ -f "$PROFILE_DATA_FILE" ] && [ ! "$PROFILE_RAW_FILE" -nt "$PROFILE_DATA_FILE" ]; then
        return
    fi

    if [ ! -f "$PROFILE_RAW_FILE" ]; then
        exit_failure "Profile data '$PROFILE_DATA_FILE' not found. Run the profile build executable first to generate '$PROFILE_RAW_FILE'."
    fi

    check_availability 'llvm-profdata'

    echo -e "$BUILD_TYPE_COLOR""Merging profile data '$PROFILE_RAW_FILE' -> '$PROFILE_DATA_FILE'""$RESET_COLOR"

    llvm-profdata merge \
        -o "$PROFILE_DATA_FILE" \
        "$PROFILE_RAW_FILE" || exit_failure "Failed to merge profile data '$PROFILE_RAW_FILE'."
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


# Remove all object files for the selected build type.
remove_object_files() {
    # Release
    if [ "$BUILD_TYPE" -eq "${BUILD_TYPES[RELEASE]}" ]; then
        fd -I -e o -x rm {}

    else
        local fd_args=(-I -e o)

        if [ ${`#staticParts`[@]} -ne 0 ]; then
            for static_part in "${staticParts[@]}"; do
                fd_args+=(-E "$static_part")
            done
        fi

        fd -I -e o "${fd_args[@]}" -x rm {}
    fi
}

# Add disabled-optimization flags to every build mode when requested.
disable_optimizations_if_requested() {
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
}

# Add Clang-specific warnings, coverage flags, and sanitizer flags.
apply_clang_flags() {
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

# Apply the selected build type flags and defines.
apply_build_type_flags() {
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

        prepare_profile_data

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
}

# Apply hot reload flags and defines when hot reload is enabled.
apply_hot_reload_flags() {
    # Hot reload
    if [ -n "${ENABLE_HOT_RELOAD+x}" ]; then
        echo -e "$BUILD_TYPE_COLOR"'Building with hot reload'"$RESET_COLOR"

        BUILD_C_FLAGS="$BUILD_C_FLAGS $BUILD_C_FLAGS_HOT_RELOAD"
        BUILD_CPP_FLAGS="$BUILD_CPP_FLAGS $BUILD_CPP_FLAGS_HOT_RELOAD"
        LINK_FLAGS="$LINK_FLAGS $LINK_FLAGS_HOT_RELOAD"
        BUILD_DEFINES+=("${BUILD_DEFINES_HOT_RELOAD[@]}")
    fi
}

# Configure compiler wrappers and verify that the selected compilers are available.
configure_compilers() {
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
}

# Generate the compiler define flags string and print it.
generate_defines() {
    if [ ${#BUILD_DEFINES[@]} -ne 0 ]; then
        printf -v definesAsString -- "-D %s " "${BUILD_DEFINES[@]}"
        echo -e "$DEFINES_COLOR""$definesAsString""$RESET_COLOR"
    fi
}

# Generate include paths from configured build parts and print them.
generate_includes() {
    mapfile -t new_build_includes < <(printf -- "%s/include""\n" "${partsToBuild[@]}" "${staticParts[@]}")

    BUILD_INCLUDES+=("${new_build_includes[@]}")

    if [ -n "$testsMainPackage" ]; then
        BUILD_INCLUDES+=("$testsMainPackage"'/include')
    fi

    if [ ${#BUILD_INCLUDES[@]} -ne 0 ]; then
        printf -v includesAsString -- "-I $SCRIPT_DIRECTORY/%s " "${BUILD_INCLUDES[@]}"
        echo -en "$INCLUDES_COLOR"
        printf -- "-I %s " "${BUILD_INCLUDES[@]}"
        echo -e "$RESET_COLOR"
    fi
}

# Resolve pkg-config build and link flags for a list of external libraries.
resolve_external_libraries() {
    local -n external_libraries_reference="$1"
    local build_flags_variable="$2"
    local link_flags_variable="$3"
    local external_libraries_as_string
    local external_libraries_build_flags
    local external_libraries_link_flags

    if [ ${#external_libraries_reference[@]} -ne 0 ]; then
        printf -v external_libraries_as_string -- "%s " "${external_libraries_reference[@]}"

        echo -e '\n'"$EXTERNAL_LIBRARIES_COLOR""$external_libraries_as_string""$RESET_COLOR"
        external_libraries_build_flags="$(pkg-config --static --cflags "$external_libraries_as_string")"' '

        SEARCH_STATUS=$?

        if [ $SEARCH_STATUS -ne 0 ]; then
            exit $SEARCH_STATUS
        fi

        printf -v "$build_flags_variable" -- "%s" "$external_libraries_build_flags"
        echo -e "$INCLUDES_COLOR""${!build_flags_variable}""$RESET_COLOR"
        external_libraries_link_flags="$(pkg-config --static --libs "$external_libraries_as_string")"' '

        SEARCH_STATUS=$?

        if [ $SEARCH_STATUS -ne 0 ]; then
            exit $SEARCH_STATUS
        fi

        printf -v "$link_flags_variable" -- "%s" "$external_libraries_link_flags"
        echo -e "$LIBRARIES_COLOR""${!link_flags_variable}""$RESET_COLOR"
    fi
}

# Remember the hash of an existing archive before it is rebuilt.
remember_existing_output_hash() {
    local output_file="$1"

    if [ -f "$BUILD_DIRECTORY/$output_file" ]; then
        processedFilesHashes["$output_file"]="$($HASH_FUNCTION "$BUILD_DIRECTORY/$output_file" | cut -d ' ' -f1)"
    fi
}

# Run build_module.sh for a configured package, either in the foreground or background.
run_build_module() {
    local output_file="$1"
    local package_directory="$2"
    local c_flags="$3"
    local cpp_flags="$4"
    local rebuild_flag="$5"
    local module_kind="$6"
    local run_in_background="${7:-}"

    if [ -n "$run_in_background" ]; then
        OUTPUT_FILE="$output_file" \
            './build_module.sh' \
            "$package_directory" \
            "$c_flags" \
            "$cpp_flags" \
            "$definesAsString" \
            "$includesAsString" \
            "$rebuild_flag" \
            "$module_kind" &

        processIDs+=($!)
    else
        OUTPUT_FILE="$output_file" \
            './build_module.sh' \
            "$package_directory" \
            "$c_flags" \
            "$cpp_flags" \
            "$definesAsString" \
            "$includesAsString" \
            "$rebuild_flag" \
            "$module_kind"

        BUILD_STATUS=$?

        if [ $BUILD_STATUS -ne 0 ]; then
            exit_failure
        fi
    fi
}

# Wait for all background build processes and fail when any process fails.
wait_for_processes() {
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
}

# Check whether an archive should be relinked into a shared object.
needs_shared_object_relink() {
    local processed_file="$1"
    local output_file="$2"

    [ ! -f "$BUILD_DIRECTORY/$output_file" ] || [ "$($HASH_FUNCTION "$BUILD_DIRECTORY/$processed_file" | cut -d ' ' -f1)" != "${processedFilesHashes["$processed_file"]}" ]
}

# Link an archive into a shared object and track the background linker process.
link_shared_object_from_archive() {
    local processed_file="$1"
    local output_file="$2"
    local message_prefix="$3"
    local change_to_build_directory="${4:-}"

    echo "Linking $message_prefix$output_file"

    if [ -n "$change_to_build_directory" ]; then
        cd "$BUILD_DIRECTORY" || exit_failure
    fi

    $COMPILER -shared -nostdlib $LINK_FLAGS '-Wl,--whole-archive' "$BUILD_DIRECTORY/$processed_file" '-Wl,--no-whole-archive' -o "$BUILD_DIRECTORY/""$output_file" &

    if [ -n "$change_to_build_directory" ]; then
        cd - >'/dev/null' || exit_failure
    fi

    export NEED_HOT_RELOAD

    processIDs+=($!)
}

# Strip sections and section headers from a built executable when requested.
strip_executable_if_requested() {
    local executable_name="$1"

    if [ -n "${STRIP_EXECUTABLE+x}" ]; then
        if [ ${#EXECUTABLE_SECTIONS_TO_STRIP[@]} -ne 0 ]; then
            printf -v sectionsToStripAsString -- "--remove-section %s " "${EXECUTABLE_SECTIONS_TO_STRIP[@]}"
            echo -e "$SECTIONS_TO_STRIP_COLOR""$sectionsToStripAsString""$RESET_COLOR"
        fi

        objcopy "$BUILD_DIRECTORY/$executable_name" $sectionsToStripAsString

        strip --strip-section-headers "$BUILD_DIRECTORY/$executable_name"
    fi
}

clear

cd "$SCRIPT_DIRECTORY" || exit

source './config.sh' && {

    check_availability 'fd'

    mkdir -p "$BUILD_DIRECTORY"

    # Remove all object files
    remove_object_files

    disable_optimizations_if_requested

    # Clang-specific flags
    apply_clang_flags

    apply_build_type_flags

    apply_hot_reload_flags

    configure_compilers

    generate_defines

    # Generate includes
    generate_includes

    resolve_external_libraries EXTERNAL_LIBRARIES_TO_LINK externalLibrariesBuildFlagsAsString externalLibrariesLinkFlagsAsString

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

            remember_existing_output_hash "$OUTPUT_FILE"

            run_build_module \
                "$OUTPUT_FILE" \
                "$partToBuild" \
                "$BUILD_C_FLAGS $externalLibrariesBuildFlagsAsString" \
                "$BUILD_CPP_FLAGS $externalLibrariesBuildFlagsAsString" \
                "$([ -n "${REBUILD_PARTS+x}" ] && echo 1 || echo 0)" \
                "module" \
                "background"
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

                remember_existing_output_hash "$OUTPUT_FILE"

                if [ -z "${REBUILD_STATIC_PARTS+x}" ]; then
                    if [ -f "$BUILD_DIRECTORY/$OUTPUT_FILE" ]; then
                        printf -- "%bSkipping static '%-${MODULE_NAME_FIELD_WIDTH}s — '%s' already exists.%b\n" "$SKIPPING_PART_IN_BUILD_COLOR" "$staticPart'" "$OUTPUT_FILE" "$RESET_COLOR"

                        continue
                    fi
                fi

                run_build_module \
                    "$OUTPUT_FILE" \
                    "$staticPart" \
                    "$BUILD_C_FLAGS $externalLibrariesBuildFlagsAsString" \
                    "$BUILD_CPP_FLAGS $externalLibrariesBuildFlagsAsString" \
                    "$([ -n "${REBUILD_STATIC_PARTS+x}" ] && echo 1 || echo 0)" \
                    "static" \
                    "background"
            } || exit_failure

            unset FILES_TO_INCLUDE FILES_TO_COMPILE

            BUILD_STATUS=$?

            if [ $BUILD_STATUS -ne 0 ]; then
                exit_failure
            fi
        done
    }

    wait_for_processes

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

            if needs_shared_object_relink "$processedFile" "$outputFile"; then
                link_shared_object_from_archive "$processedFile" "$outputFile" "static "
            fi
        done

        wait_for_processes

        # Convert to shared objects
        for processedFile in "${processedFiles[@]}"; do
            outputFile="${processedFile%.a}.so"

            if needs_shared_object_relink "$processedFile" "$outputFile"; then
                link_shared_object_from_archive "$processedFile" "$outputFile" "" "change_to_build_directory"
            fi
        done

        wait_for_processes

        if [ -z "${NEED_HOT_RELOAD+x}" ]; then
            # Link root that will have DT_NEEDED for all shared objects
            source "$rootSharedObjectName/config.sh" && {
                OUTPUT_FILE="$rootSharedObjectName"'.a'

                run_build_module \
                    "$OUTPUT_FILE" \
                    "$rootSharedObjectName" \
                    "$BUILD_C_FLAGS" \
                    "$BUILD_CPP_FLAGS" \
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

                run_build_module \
                    "$OUTPUT_FILE" \
                    "$executableMainPackage" \
                    "$BUILD_C_FLAGS $externalLibrariesBuildFlagsAsString" \
                    "$BUILD_CPP_FLAGS $externalLibrariesBuildFlagsAsString" \
                    "$([ -n "${REBUILD_PARTS+x}" ] && echo 1 || echo 0)" \
                    "module"
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

            strip_executable_if_requested "$EXECUTABLE_NAME"
        fi
    }

    # Build tests
    if [ "$BUILD_TYPE" -eq "${BUILD_TYPES[TESTS]}" ]; then
        resolve_external_libraries EXTERNAL_LIBRARIES_TO_LINK_TESTS externalLibrariesTestsBuildFlagsAsString externalLibrariesTestsLinkFlagsAsString

        for testToBuild in "${testsToBuild[@]}"; do
            export FILES_TO_INCLUDE=""
            export FILES_TO_COMPILE=""

            source "$testToBuild/$TESTS_DIRECTORY/config.sh" && {
                OUTPUT_FILE='lib'"$testToBuild"'_test.a'

                run_build_module \
                    "$OUTPUT_FILE" \
                    "$testToBuild/$TESTS_DIRECTORY" \
                    "$BUILD_C_FLAGS $externalLibrariesBuildFlagsAsString $externalLibrariesTestsBuildFlagsAsString" \
                    "$BUILD_CPP_FLAGS $externalLibrariesBuildFlagsAsString $externalLibrariesTestsBuildFlagsAsString" \
                    "$([ -n "${REBUILD_PARTS+x}" ] && echo 1 || echo 0)" \
                    "module" \
                    "background"
            } || exit_failure

            unset FILES_TO_INCLUDE FILES_TO_COMPILE

            BUILD_STATUS=$?

            if [ $BUILD_STATUS -ne 0 ]; then
                exit_failure
            fi
        done

        wait_for_processes

        # Build tests main package
        {
            export FILES_TO_INCLUDE=""
            export FILES_TO_COMPILE=""

            source "$testsMainPackage/config.sh" && {
                run_build_module \
                    'lib'"$testsMainPackage"'.a' \
                    "$testsMainPackage" \
                    "$BUILD_C_FLAGS $externalLibrariesBuildFlagsAsString $externalLibrariesTestsBuildFlagsAsString" \
                    "$BUILD_CPP_FLAGS $externalLibrariesBuildFlagsAsString $externalLibrariesTestsBuildFlagsAsString" \
                    "$([ -n "${REBUILD_PARTS+x}" ] && echo 1 || echo 0)" \
                    "module"
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

            strip_executable_if_requested "$EXECUTABLE_NAME_TESTS"
        }
    fi

} || exit_failure

cd - >'/dev/null' || exit_failure
