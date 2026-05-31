#!/bin/bash
TARGET_DIRECTORY=$1
MODULE_TYPE_NAME=$7

# Build a space-separated list of paths rooted at the target directory.
build_target_path_list() {
    local files=$1

    echo $files | sed "s~[^ ]*~$TARGET_DIRECTORY/&~g"
}

# Check that each resolved path exists unless the input represents a glob without matches.
check_existense() {
    local files=$1

    # No glob
    if [[ $files == */ ]]; then
        return
    fi

    for file in "${files[@]}"; do
        if [ ! -f "$file" ]; then
            exit_failure "$(printf -- "Invalid %s '%-$((MODULE_NAME_FIELD_WIDTH + 1))s — invalid glob '%s'.\n" "$MODULE_TYPE_NAME" "$TARGET_DIRECTORY'" "$file")"
        fi
    done
}

# Prepend '-I ' to each include path
format_include_paths() {
    IFS=' ' read -r -a new_include_paths <<<"$INCLUDE_PATHS"

    printf -v INCLUDE_PATHS -- "-I %s " "${new_include_paths[@]}"
}

# Find the newest source or header file in the current target directory.
find_newest_file() {
    fd -e c -e cpp -e h -e hpp . | xargs stat --format '%Y %n' | sort -n | tail -1 | cut -d' ' -f2-
}

# Print the message used when the current module does not need to be rebuilt.
print_skip_message() {
    printf -- "%bSkipping %s '%-${MODULE_NAME_FIELD_WIDTH}s — '%s' already exists.%b\n" \
        "$SKIPPING_PART_IN_BUILD_COLOR" \
        "$MODULE_TYPE_NAME" \
        "$TARGET_DIRECTORY'" \
        "$OUTPUT_FILE" \
        "$RESET_COLOR"
}

# Determine whether the target module needs to be rebuilt.
check_build_needed() {
    cd "$TARGET_DIRECTORY" || exit

    # TODO: Better name
    newest_file=$(find_newest_file)

    if [[ "$6" -eq 1 ]] ||
        { [[ ! -f "$BUILD_DIRECTORY/$OUTPUT_FILE" ]] ||
            { [[ -f "$newest_file" ]] &&
                [[ "$newest_file" -nt "$BUILD_DIRECTORY/$OUTPUT_FILE" ]]; }; }; then
        needBuild=1

    else
        print_skip_message
    fi

    cd - >'/dev/null' || exit
}

# Invoke make with the configured build arguments for the current module.
make_module() {
    make \
        "BUILD_C_FLAGS=$2" \
        "BUILD_CPP_FLAGS=$3" \
        "DEFINES=$4" \
        "INCLUDES=$5" \
        "FILES_TO_INCLUDE=$INCLUDE_PATHS" \
        "FILES_TO_COMPILE=$COMPILE_PATHS"
}

# Move the built output file into the shared build directory.
move_output_file() {
    mv "$OUTPUT_FILE" "$BUILD_DIRECTORY"
}

# Format module files using the repository clang-format configuration.
format_module_files() {
    cd $TARGET_DIRECTORY &&
        clang-format --style="file:$SCRIPT_DIRECTORY/.clang-format" \
            -i \
            $(echo $FILES_TO_INCLUDE $FILES_TO_COMPILE) &&
        cd "$SCRIPT_DIRECTORY" || exit
}

# Build the current module and format its source files after a successful build.
build_module() {
    source "$SCRIPT_DIRECTORY/config.sh" &&
        make clean &&
        if make_module "$@"; then
            move_output_file &&
                format_module_files

        else
            exit_failure "$(printf -- "Invalid %s '%-${MODULE_NAME_FIELD_WIDTH}s — failed to make.\n" "$MODULE_TYPE_NAME" "$TARGET_DIRECTORY'")"
        fi
}

INCLUDE_PATHS=$(build_target_path_list "$FILES_TO_INCLUDE")
COMPILE_PATHS=$(build_target_path_list "$FILES_TO_COMPILE")

check_existense $INCLUDE_PATHS
check_existense $COMPILE_PATHS

format_include_paths

needBuild=0

# Check if build is needed
check_build_needed "$@"

if ((needBuild)); then
    build_module "$@"
fi
