#!/bin/zsh
set -euo pipefail

config=script/input/config.json

trap chain EXIT

chains=(eth arb bnb matic ftm op linea blast base zkevm manta sei)

echo $chains | tr ' ' '\n' | parallel "\
    echo \"🔗🔗🔗🔗🔗🔗🔗🔗🔗🔗🔗🔗 {} 🚀🚀🚀🚀🚀🚀🚀🚀🚀🚀🚀🚀\";\
    chain {};\
    forge script Deploy --broadcast \$([[ -n \$ETHERSCAN_API_KEY ]] && echo '--verify --retries 100')" | \
    tee >( \
    grep ': address ' | sed 's/: address / /' | while read c a; do; [[ $a != $(jq -r ".$c" $config) ]] && echo "❌ address mismatch: $c $a"; done; \
        )


