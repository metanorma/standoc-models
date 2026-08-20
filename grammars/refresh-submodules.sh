#!/usr/bin/env bash
# Refresh grammar submodules to their latest upstream main and record the
# resulting versions in versions.json.
#
# This is the ONLY script in the grammar build that touches the network.
# Run it manually when a new relaton-*/basicdoc/requirements release should
# be pulled in, then commit the updated submodule pins and run ./make.sh.
set -euo pipefail
cd "$(dirname "$0")"

echo "Updating submodules..."
rm -f relaton-models/grammars/biblio.rng basicdoc-models/grammars/basicdoc.rng
git submodule update --remote

echo "{" > versions.json

record_version() {
  local dir=$1 key=$2
  (
    cd "$dir"
    git checkout main
    git pull
    local tag
    tag=$(git tag --sort=committerdate | tail -1)
    echo "\"$key\": \"$tag\"," >> ../../versions.json
  )
}

record_version relaton-models/grammars relaton-models
record_version basicdoc-models/grammars basicdoc-models
record_version metanorma-requirements-models/grammars metanorma-requirements-models

self_tag=$(git tag --sort=committerdate | tail -1)
echo "\"metanorma-model\": \"$self_tag\"," >> versions.json
date=$(TZ=GMT date +"%Y-%m-%dT%H:%M:%SZ")
echo "\"date\": \"$date\"" >> versions.json
echo "}" >> versions.json
