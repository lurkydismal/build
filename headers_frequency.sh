#!/bin/bash
fd -e cpp src |
    xargs rg '^#include' |
    rg -o '#include\s+[<"].+[>"]' |
    sort | uniq -c | sort -n
