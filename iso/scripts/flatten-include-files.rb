#!/usr/bin/env ruby
# Copies the submodule-sourced .rnc grammars (basicdoc, biblio, reqt,
# relaton-*) into the shared grammars/ directory at the monorepo root,
# so the lutaml-xsd package build and trang compilation find them.
# Runs from any working directory; resolves the repo root from __dir__.

require "fileutils"

repo_root = File.expand_path("../..", __dir__) # iso/scripts -> repo root
grammars = File.join(repo_root, "grammars")

Dir.glob(File.join(grammars, "*", "grammars", "*.rnc")).each do |file|
  dest = File.join(grammars, File.basename(file))
  FileUtils.cp(file, dest) unless File.exist?(dest)
end

# mathml vendored directory (referenced by basicdoc.rnc external)
mathml_src = File.join(grammars, "basicdoc-models", "grammars", "mathml")
mathml_dest = File.join(grammars, "mathml")
FileUtils.cp_r(mathml_src, mathml_dest) if File.directory?(mathml_src) && !File.directory?(mathml_dest)
