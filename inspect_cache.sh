#!/bin/bash
export MY_TEMP_FILE="${MY_TEMP_FILE:-$(mktemp)}"

valgrind \
    --tool=cachegrind \
    --cachegrind-out-file="$MY_TEMP_FILE" \
    ./out/main.out_test && \
    cg_annotate "$MY_TEMP_FILE" | \
    nvim -
