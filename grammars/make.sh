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
cp relaton-models/grammars/biblio.rnc .
cp relaton-models/grammars/biblio-standoc.rnc .
cp relaton-models/grammars/biblio-compile.rnc .
cp basicdoc-models/grammars/basicdoc.rnc .
# basicdoc.rnc references the W3C MathML grammar via `external "mathml/..."`;
# vendor those sources so trang can resolve them at compile time.
cp -r basicdoc-models/grammars/mathml .
cp metanorma-requirements-models/grammars/reqt.rnc .

# relaton-<flavor>.rnc flavour overlays are tracked here (absorbed from the
# former per-flavour relaton-model-* repositories, now unified upstream in
# relaton/relaton-models).

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

for i in biblio biblio-compile biblio-standoc basicdoc reqt relaton-ieee relaton-iso relaton-iec relaton-bsi relaton-gb relaton-mpfa relaton-bipm relaton-w3c relaton-3gpp relaton-csa relaton-cc relaton-ietf relaton-iho relaton-itu relaton-m3aawg relaton-nist relaton-ribose relaton-ogc relaton-un relaton-cen relaton-ecma relaton-etsi relaton-plateau relaton-cie relaton-iana relaton-omg relaton-oasis relaton-jis relaton-ccsds standoc standoc-presentation biblio-presentation standoc-collection standoc-compile standoc-presentation-compile isostandard isostandard-compile isostandard-amd iec cc gbstandard ribose ieee ogc nist itu ietf generic iho bipm bsi jis plateau relaton-ieee-compile relaton-iso-compile relaton-iec-compile relaton-bsi-compile relaton-gb-compile relaton-mpfa-compile relaton-bipm-compile relaton-w3c-compile relaton-3gpp-compile relaton-csa-compile relaton-cc-compile relaton-ietf-compile relaton-iho-compile relaton-itu-compile relaton-m3aawg-compile relaton-nist-compile relaton-ribose-compile relaton-ogc-compile relaton-un-compile relaton-cen-compile relaton-ecma-compile relaton-etsi-compile relaton-cie-compile relaton-iana-compile relaton-omg-compile relaton-oasis-compile relaton-jis-compile relaton-plateau-compile relaton-ccsds-compile
do
  echo $i
  trang -I rnc -O rng $i.rnc $i.rng
done

bundle exec ruby test.rb

if [ -e ../../metanorma-standoc/lib/metanorma/standoc ]
then
  sh copy.sh
fi
