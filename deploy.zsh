#!/bin/zsh
set -euo pipefail

config=script/input/config.json

trap chain EXIT

chains=(eth arb bnb matic ftm op linea blast base zkevm manta sei sonic zircuit)

echo $chains | tr ' ' '\n' | parallel --keep-order "
    echo \"\n🔗🔗🔗🔗🔗🔗🔗🔗🔗🔗🔗🔗 {} 🚀🚀🚀🚀🚀🚀🚀🚀🚀🚀🚀🚀\n\";
    chain {};
    forge script Deploy --broadcast --verify \
        \$([[ -n \$VERIFIER ]] && echo --verifier \$VERIFIER)" |
    tee >(
        grep ': address ' | sed 's/: address / /' | while read c a; do;
            [[ $a != $(jq -r ".$c" $config) ]] && echo "❌ address mismatch: $c $a";
        done;
        )

