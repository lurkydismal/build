#!/bin/bash
export partsToBuild=(
    "example"
)
export testsToBuild=(
    "example"

    "arhodigp"
    "logg"
    "stdfunc"

    "test"
)
export staticParts=(
    "arhodigp"
    "logg"
    "stdfunc"
)
export rootSharedObjectName="root"

export executableMainPackage='main'
export testsMainPackage='test'

BUILD_DEFINES+=()

BUILD_DEFINES_RELEASE+=(
    "NDEBUG"
)

BUILD_DEFINES_PROFILE+=(
    "NDEBUG"
)

BUILD_INCLUDES+=()

# -l link
LIBRARIES_TO_LINK+=(
    "mimalloc"
    "unwind"

    "stdc++exp"
)

LIBRARIES_TO_LINK_TESTS+=(
    "snappy"
    "zstd"
)

# pkg-config
EXTERNAL_LIBRARIES_TO_LINK+=()

EXTERNAL_LIBRARIES_TO_LINK_TESTS+=(
    "gtest"
    "gmock"
)

export MODULE_NAME_FIELD_WIDTH=24

# Tests
if [ "$BUILD_TYPE" -eq 3 ]; then
    ((MODULE_NAME_FIELD_WIDTH += 6))
fi

export FAIL_COLOR="$RED_LIGHT_COLOR"
export BUILD_TYPE_COLOR="$PURPLE_LIGHT_COLOR"
export DEFINES_COLOR="$CYAN_LIGHT_COLOR"
export INCLUDES_COLOR="$BLUE_LIGHT_COLOR"
export LIBRARIES_COLOR="$BLUE_LIGHT_COLOR"
export EXTERNAL_LIBRARIES_COLOR="$BLUE_LIGHT_COLOR"
export PARTS_TO_BUILD_COLOR="$YELLOW_COLOR"
export SKIPPING_PART_IN_BUILD_COLOR="$GREEN_LIGHT_COLOR"
export BUILT_EXECUTABLE_COLOR="$GREEN_LIGHT_COLOR"
export SECTIONS_TO_STRIP_COLOR="$RED_LIGHT_COLOR"
