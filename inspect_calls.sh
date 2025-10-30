#!/bin/bash
export MY_TEMP_FILE="${MY_TEMP_FILE:-$(mktemp)}"

valgrind \
    --tool=callgrind \
    --dump-instr=yes \
    --collect-jumps=yes \
    --callgrind-out-file="$MY_TEMP_FILE" \
    ./out/main.out_test && \
    kcachegrind "$MY_TEMP_FILE"
