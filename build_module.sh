#!/bin/bash
TARGET_DIRECTORY=$1
MODULE_TYPE_NAME=$7

INCLUDE_PATHS=$(echo $FILES_TO_INCLUDE | sed "s~[^ ]*~$TARGET_DIRECTORY/&~g")
COMPILE_PATHS=$(echo $FILES_TO_COMPILE | sed "s~[^ ]*~$TARGET_DIRECTORY/&~g")

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

check_existense $INCLUDE_PATHS
check_existense $COMPILE_PATHS

# Prepend '-I ' to each include path
{
    IFS=' ' read -r -a new_include_paths <<<"$INCLUDE_PATHS"

    printf -v INCLUDE_PATHS -- "-I %s " "${new_include_paths[@]}"
}

needBuild=0

# Check if build is needed
{
    cd "$TARGET_DIRECTORY" || exit

    # TODO: Better name
    newest_file=$(fd -e c -e cpp -e h -e hpp . | xargs stat --format '%Y %n' | sort -n | tail -1 | cut -d' ' -f2-)

    if [[ "$6" -eq 1 ]] ||
        { [[ ! -f "$BUILD_DIRECTORY/$OUTPUT_FILE" ]] ||
            { [[ -f "$newest_file" ]] &&
                [[ "$newest_file" -nt "$BUILD_DIRECTORY/$OUTPUT_FILE" ]]; }; }; then
        needBuild=1

    else
        printf -- "%bSkipping %s '%-${MODULE_NAME_FIELD_WIDTH}s — '%s' already exists.%b\n" \
            "$SKIPPING_PART_IN_BUILD_COLOR" \
            "$MODULE_TYPE_NAME" \
            "$TARGET_DIRECTORY'" \
            "$OUTPUT_FILE" \
            "$RESET_COLOR"
    fi

    cd - >'/dev/null' || exit
}

if ((needBuild)); then
    source "$SCRIPT_DIRECTORY/config.sh" &&
        make clean &&
        if make \
            "BUILD_C_FLAGS=$2" \
            "BUILD_CPP_FLAGS=$3" \
            "DEFINES=$4" \
            "INCLUDES=$5" \
            "FILES_TO_INCLUDE=$INCLUDE_PATHS" \
            "FILES_TO_COMPILE=$COMPILE_PATHS"; then
            mv "$OUTPUT_FILE" "$BUILD_DIRECTORY" &&
                cd $TARGET_DIRECTORY &&
                clang-format --style="file:$SCRIPT_DIRECTORY/.clang-format" \
                    -i \
                    $(echo $FILES_TO_INCLUDE $FILES_TO_COMPILE) &&
                cd "$SCRIPT_DIRECTORY" || exit

        else
            exit_failure "$(printf -- "Invalid %s '%-${MODULE_NAME_FIELD_WIDTH}s — failed to make.\n" "$MODULE_TYPE_NAME" "$TARGET_DIRECTORY'")"
        fi
fi
