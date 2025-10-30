#!/bin/bash
export MY_TEMP_FILE="${MY_TEMP_FILE:-$(mktemp)}"

valgrind \
    --tool=massif \
    --massif-out-file="$MY_TEMP_FILE" \
    ./out/main.out_test && \
    massif-visualizer "$MY_TEMP_FILE"
