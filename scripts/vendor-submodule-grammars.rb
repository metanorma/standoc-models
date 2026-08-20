#!/usr/bin/env ruby
# Vendors the submodule-sourced .rnc grammars (basicdoc, biblio, reqt, the
# shared relaton layers and the per-flavour relaton overlays) into grammars/
# at the monorepo root, so trang compilation (grammars/make.sh) and the
# lutaml-xsd package build (deploy.yml) find them.
# Runs from any working directory; resolves the repo root from __dir__.

require "fileutils"

repo_root = File.expand_path("..", __dir__) # scripts -> repo root
grammars = File.join(repo_root, "grammars")

# Shared layers: relaton-models/grammars/*.rnc, basicdoc-models, requirements
Dir.glob(File.join(grammars, "*", "grammars", "*.rnc")).each do |file|
  FileUtils.cp(file, File.join(grammars, File.basename(file)))
end

# Per-flavour relaton overlays: relaton-models/<flavour>/grammars/*.rnc
Dir.glob(File.join(grammars, "*", "*", "grammars", "*.rnc")).each do |file|
  FileUtils.cp(file, File.join(grammars, File.basename(file)))
end

# mathml sources (basicdoc.rnc references them via `external "mathml/..."`)
mathml_src = File.join(grammars, "basicdoc-models", "grammars", "mathml")
mathml_dest = File.join(grammars, "mathml")
FileUtils.rm_rf(mathml_dest) if Dir.exist?(mathml_dest)
FileUtils.cp_r(mathml_src, mathml_dest) if File.directory?(mathml_src)
