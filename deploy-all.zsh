#!/bin/zsh

set -euo pipefail

trap chain EXIT

chains=(eth arb bnb matic ftm op)

echo $chains | tr ' ' '\n' | parallel "echo \"🔗🔗🔗🔗🔗🔗🔗🔗🔗🔗🔗🔗 🚀🚀🚀🚀🚀🚀🚀🚀🚀🚀🚀🚀 {}\"; source setchain {}; forge script Deploy --broadcast --verify --retries 100"

