#!/usr/bin/env bash
# Deterministic grammar build: vendor .rnc from the checked-out submodule
# pins, compile RNC -> RNG with trang, validate with test.rb.
#
# This script never updates submodules and never writes versions.json;
# run refresh-submodules.sh for that. Requires submodules to be initialized:
#   git submodule update --init --recursive
set -euo pipefail
cd "$(dirname "$0")"

# --- vendor grammar inputs from the submodule pins -------------------------
# All .rnc vendoring (shared layers, per-flavour relaton overlays, mathml)
# lives in scripts/vendor-submodule-grammars.rb — the single implementation,
# shared with deploy.yml.
ruby ../scripts/vendor-submodule-grammars.rb

# a failed copy above would otherwise surface only as an unrelated trang
# "file not found" error at compile time
for f in biblio.rnc biblio-standoc.rnc biblio-compile.rnc basicdoc.rnc reqt.rnc
do
  if [[ ! -s $f ]]; then
    echo "ERROR: $f is missing or empty; run 'git submodule update --init --recursive' and retry." >&2
    exit 1
  fi
done
if [[ ! -d mathml ]]; then
  echo "ERROR: mathml/ directory is missing; run 'git submodule update --init --recursive' and retry." >&2
  exit 1
fi

# --- trang: pinned, no drifting-main clones --------------------------------
# Resolution order: TRANG_JAR env -> trang on PATH (e.g. Homebrew) ->
# one-time build of the pinned ref under vendor/ (cacheable in CI).
JING_TRANG_REF="V20241231"

if [[ -n "${TRANG_JAR:-}" ]]; then
  trang() { java -jar "$TRANG_JAR" "$@"; }
elif command -v trang >/dev/null 2>&1; then
  trang() { command trang "$@"; }
else
  TRANG_BUILD="vendor/jing-trang-$JING_TRANG_REF/build/trang.jar"
  if [[ ! -f "$TRANG_BUILD" ]]; then
    rm -rf "vendor/jing-trang-$JING_TRANG_REF" # partial build from an interrupted run
    git clone --depth 1 --branch "$JING_TRANG_REF" https://github.com/relaxng/jing-trang.git "vendor/jing-trang-$JING_TRANG_REF"
    (cd "vendor/jing-trang-$JING_TRANG_REF" && ./ant)
  fi
  trang() { java -jar "$TRANG_BUILD" "$@"; }
fi

echo "Compiling..."

# Compile set = every .rnc in the hub (tracked sources + vendored
# submodule inputs alike; new flavour grammars compile automatically).
for i in $(ls *.rnc | sed 's/\.rnc$//' | sort)
do
  echo $i
  trang -I rnc -O rng "$i.rnc" "$i.rng"
done

bundle exec ruby test.rb

if [ -e ../../metanorma-standoc/lib/metanorma/standoc ]
then
  sh copy.sh
fi
