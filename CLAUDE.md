# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this repository is

Consolidated monorepo of the Metanorma standoc document-model family (per metanorma-core#16). It replaced the per-flavour `metanorma-model-*` repositories.

**The models are the LML files.** `<flavour>/models/*.lml` are the information models — the single source of truth. RNC grammars are implementation files accompanying the models, hand-maintained today and slated for retirement by the model-driven programme (issue #181: generate schemas/classes from LML). Never describe, structure, or refactor around RNC as if they were the model definitions.

## Layout

- `flavors.txt` — single source of the flavour list; read by the root `Makefile`, `deploy.yml`, and the metanorma/ci path-filter job. Add flavours here, nowhere else.
- `<flavour>/` — one directory per flavour: `models/*.lml` (diagram views; `models/<subdir>/*.lml` are definition modules included by the views — the Makefile wildcard is non-recursive by design), `images/*.png` (generated output, committed), `build-config.yml` (LXR schema set), `README.adoc`.
- `grammars/` — the RNC/RNG implementation hub (formerly `metanorma-model-iso`): shared layers (`standoc.rnc`, `standoc-presentation.rnc`, `basicdoc.rnc`, `biblio*.rnc`, `reqt.rnc`) plus per-flavour document grammars.
- `grammars/{relaton-models,basicdoc-models,metanorma-requirements-models}/` — git submodules. Relaton overlays (`relaton-<flavour>.rnc`) are **vendored from the submodule pin at build time** (`grammars/make.sh`) and gitignored — they are not tracked here. The relaton-models submodule pins the unified relaton-models repo, which carries the merged histories of all former `relaton-model-{flavor}` repos.
- `scripts/flatten-include-files.rb` — flattens LML includes for single-file exports.
- Legacy leftovers from the pre-consolidation repos (some flavour `grammar/` dirs, `models/models/*.yml` LutaML-YAML definitions, `style.uml.inc` PlantUML skins) may still exist in flavour dirs; `grammars/` is the only maintained grammar home.

## Commands

Model diagrams (root Rakefile; requires `bundle install` + Graphviz `dot`):

```
rake              # all flavours
rake iso          # one flavour
rake verify       # assert every committed .png really is a PNG
rake clean
```

Grammar build (deterministic; requires submodules initialized):

```
git submodule update --init --recursive
cd grammars && ./make.sh        # vendor .rnc from pins -> trang RNC->RNG -> bundle exec ruby test.rb
cd grammars && ./refresh-submodules.sh   # the ONLY network path; updates pins + versions.json
```

- Trang resolution order: `TRANG_JAR` env → `trang` on `PATH` → one-time pinned build (`V20241231`) under `grammars/vendor/` (gitignored).
- `grammars/copy.sh` vendors compiled `.rng` into sibling `metanorma-*` gem checkouts (workspace layout); `make.sh` runs it only when the gems are present. Vendored files keep legacy `isodoc*.rng`/`standoc.*` destination names because gems load those paths.

## Invariants

- **Regeneration parity gate**: committed `.rng` must be byte-identical to regeneration from the pinned sources. Hand-edits to generated artifacts, or `.rnc` changes committed without regenerating, fail CI.
- `make.sh` never updates submodules and never writes `versions.json`; `refresh-submodules.sh` never runs as part of the build.
- No per-flavour Gemfiles or build scripts — one root `Gemfile` and one root `Rakefile` only.
- `.gitignore`: `grammars/*.rng` is ignored but committed artifacts stay tracked (the index wins over ignore); `relaton-*.rnc`, `basicdoc.rnc`, `biblio*.rnc`, `reqt.rnc`, `mathml/` are vendored, never committed.
- `deploy.yml` builds an `.lxr` package + SPA per flavour from each `build-config.yml` with `lutaml-xsd` and publishes to GitHub Pages.
- The `semx`/`fmt-*` Presentation XML contract is documented in `grammars/README.adoc`; `fmt-*` vocabulary is closed by the grammars here.
