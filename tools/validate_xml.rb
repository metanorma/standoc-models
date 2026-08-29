# frozen_string_literal: true

# Validates examples/*.xml against the compiled standoc grammar
# (grammars/standoc-compile.rng; regenerate with grammars/make.sh).

require "tmpdir"
require "jing"

ROOT = File.expand_path("..", __dir__)
GRAMMAR = File.join(ROOT, "grammars", "standoc-compile.rng")

abort "fixtures:xml: #{GRAMMAR} missing — run grammars/make.sh" unless File.file?(GRAMMAR)

# The compile grammar carries no namespace; gems inject ns= at vendoring
# time (grammars/copy.sh) — do the same here so real, namespaced instances
# validate.
NS = "https://www.metanorma.org/ns/standoc"
# Written beside the original so its relative <include href> chain resolves.
injected = File.join(ROOT, "grammars", "fixture-standoc-compile.rng")
File.write(injected, File.read(GRAMMAR).sub("<grammar ", %(<grammar ns="#{NS}" )))

Dir[File.join(ROOT, "examples", "*.xml")].sort.each do |path|
  errors = Jing.new(injected, encoding: "UTF-8").validate(path)
  if errors.empty?
    puts "fixtures:xml OK #{File.basename(path)}"
  else
    puts "fixtures:xml FAIL #{File.basename(path)}"
    errors.each { |e| puts "  #{e[:message]}" }
    exit 1
  end
end
