#!/bin/bash -e

args="$@"

find script -type f -name '*.s.sol' | sort -V | while read -r scriptname; do
    name=$(basename "$scriptname" .s.sol)
    echo "$name"
    forge script "$scriptname" $args
    echo "------"
done
