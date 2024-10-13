#!/bin/zsh

set -euo pipefail

trap chain EXIT

chains=(eth arb bnb matic ftm op linea blast base zkevm)

echo $chains | tr ' ' '\n' | parallel "\
    echo \"🔗🔗🔗🔗🔗🔗🔗🔗🔗🔗🔗🔗 🚀🚀🚀🚀🚀🚀🚀🚀🚀🚀🚀🚀 {}\";\
    chain {};\
    forge script Deploy --broadcast --verify --retries 100"

