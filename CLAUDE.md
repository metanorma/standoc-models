# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this repository is

Consolidated monorepo of the Metanorma standoc document-model family (per metanorma-core#16) — the machine-readable companion of CC/ISO 36100 "Standardization document — Document metamodel" (see the CalConnect consumer repos `cc-standard-doc` and `cc-citation-models`). It replaced the per-flavour `metanorma-model-*` repositories; their git histories are grafted here via `Merge metanorma-model-<flavour> history (unification)` commits.

**The models are the LML files.** `<flavour>/models/*.lml` are the information models — the single source of truth. RNC grammars are implementation files accompanying the models, hand-maintained today and slated for retirement by the model-driven programme (issue #181: generate schemas/classes from LML). Never describe, structure, or refactor around RNC as if they were the model definitions.

**Flavour views are fully encapsulated** (convention shared with relaton-models#70): a flavour view includes only its own module's models (`<flavour>/models/<package>/`); classes from other layers referenced in associations render as collapsed, name-only boxes. The `standoc/` base views are the exploded reference set. Do not add cross-module includes to flavour views.

## Layout

```
flavors.txt                 # single source of the flavour list
Rakefile / Gemfile          # one build, one dependency set — no per-flavour copies
scripts/vendor-submodule-grammars.rb
grammars/                   # RNC/RNG implementation hub (ONLY grammar home)
  make.sh                   # deterministic: vendor -> trang -> test.rb
  refresh-submodules.sh     # ONLY network path
  copy.sh                   # vendor .rng into sibling metanorma-* gem checkouts
  {relaton,basicdoc,metanorma-requirements}-models/   # git submodules
  standoc*.rnc, isostandard*.rnc, <flavour>.rnc, ...  # tracked sources
  *.rng                     # committed compiled artifacts (parity-gated)
<flavour>/                  # one dir per former metanorma-model-<flavour>
  models/*.lml              # diagram VIEWS (Rakefile globs non-recursively)
  models/<package>/*.lml    # definition MODULES included by the views
  models/models/*.yml       # legacy LutaML-YAML definitions (pre-LML era)
  models/*.wsd              # legacy PlantUML sources (pre-LML era)
  images/*.png              # generated diagrams, committed
  build-config.yml          # LXR schema set for Pages
  README.adoc
```

- `flavors.txt` is the single source of the flavour list — read by the root Rakefile, `deploy.yml`, and the metanorma/ci path-filter. Add flavours here, nowhere else.
- Flavour dirs hold models + docs only. **No** per-flavour `grammar/`, Gemfile, Makefile, or CI workflow.
- Hub grammar names: most flavours use `<flavour>.rnc` (e.g. `cc.rnc`, `csa.rnc`); legacy exceptions kept for gem-path compatibility — `m3d.rnc` (m3aawg), `gbstandard.rnc` (gb), `isostandard.rnc` (iso family). Do not rename without a gem-side migration.
- Relaton overlays (`relaton-<flavour>.rnc`) are **vendored from the submodule pin at build time** and gitignored — never committed here. The relaton-models submodule carries the merged histories of all former `relaton-model-{flavor}` repos.

## Commands

```
bundle install
rake                        # all flavour diagrams
rake iso                    # one flavour
rake verify                 # assert every committed .png is a real PNG
rake parity                 # layout invariants + LML-enum/RNC vocabulary parity
rake lint                   # semantic LML lint: names, duplicates, type resolution
rake fixtures               # twin XML/YAML instances (examples/)
rake schema                 # regenerate schema/standdoc-2020-12.json from the LML
rake site                   # build the model catalogue into _site/
rake clean

git submodule update --init --recursive
cd grammars && ./make.sh              # vendor -> trang -> test.rb (no network)
cd grammars && ./refresh-submodules.sh  # ONLY network path; then ./make.sh
```

- Trang resolution: `TRANG_JAR` env → `trang` on `PATH` → one-time pinned build (`V20241231`) under `grammars/vendor/` (gitignored; needs `ant` + Java).
- `grammars/copy.sh` vendors compiled `.rng` into sibling `metanorma-*` gem checkouts; `make.sh` runs it only when those gems are present. Destination filenames stay legacy (`standoc.*` / gem-local names) because gems load those paths.

## Invariants

- **Prime directive**: LML first. Model change = LML change; grammars follow.
- **Grammar artifacts are generated on demand**: `.rng` are never committed — `make.sh` compiles every `.rnc` in the hub (the compile and validation sets are derived, not hand-listed) and `test.rb` validates composites + flavour grammars; the `grammar-parity` CI job rebuilds from the pinned sources and validates the XML fixture against the fresh chain.
- `make.sh` never updates submodules and never writes `versions.json`; `refresh-submodules.sh` never runs as part of the build.
- One root `Gemfile` + one root `Rakefile`. No per-flavour build scripts.
- `.gitignore`: all `.rng` outputs and vendored inputs (`relaton-*.rnc`, `basicdoc.rnc`, `biblio*.rnc`, `reqt.rnc`, `mathml/`) are never committed. Never vendor from the basicdoc copy nested inside relaton-models — only the direct submodule pins are recorded.
- Vendoring of submodule `.rnc` has **one** implementation: `scripts/vendor-submodule-grammars.rb`. Both `grammars/make.sh` and `deploy.yml` call it.
- `deploy.yml` builds an `.lxr` package + SPA per flavour from each `build-config.yml` with `lutaml-xsd` and publishes to GitHub Pages.
- The `semx`/`fmt-*` Presentation XML contract lives in `grammars/README.adoc`; `fmt-*` vocabulary is closed by the grammars here.

## Architecture notes (do not "clean up" blindly)

- **Shared LML modules are drifted siblings, not copies.** `standoc/models/{standard_document,basic_document,relaton}/` carry the rich prose definitions; flavour copies under `bsi|cc|iso|gb/models/...` are terse stubs that have diverged. Cross-directory `include` works (lutaml-lml resolves `../../standoc/...`), but consolidating them is content-merge work for the #181 programme — do not delete the flavour copies or force-overwrite with standoc's version without an explicit content review.
- **Legacy `.wsd` and `models/models/*.yml`** are pre-LML sources kept for provenance after the history graft. The live diagram pipeline is `.lml` → `.png` only. Do not regenerate from `.wsd`.
- **`iso/plans/`** holds long-form plan-of-record docs for the schema-documentation programme (issue lineage from metanorma-model-iso#90). Not build inputs.
- **`iso/build-config-{full,small}.yml`** are alternate LXR schema sets (full vs reduced); `build-config.yml` is what `deploy.yml` consumes.
