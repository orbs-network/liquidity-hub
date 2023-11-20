#!/bin/bash

comment="// License: https://github.com/Uniswap/UniswapX/blob/4bc3d8d2f528223a0d6df5ac5348510883e9aa77/LICENSE"

dir="lib/UniswapX/src/"

# Find all .sol files and prepend the comment
find "$dir" -name '*.sol' -exec sh -c 'awk -v n=2 -v s="$1" "NR == n {print s} {print}" "$0" > temp && mv temp "$0"' {} "$comment" \;
