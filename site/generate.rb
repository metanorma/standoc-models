# frozen_string_literal: true

require "erb"
require "fileutils"
require "pathname"

module StandocSite
  Card = Struct.new(
    :flavor, :name, :title, :caption, :image, :github_url,
    keyword_init: true
  )

  Flavor = Struct.new(
    :name, :code, :kind, :clause, :description, :cards,
    :model_files, :grammar, :legacy_grammar,
    keyword_init: true
  )

  module_function

  ROOT = Pathname(__dir__).parent
  SITE = ROOT.join("site")
  OUT  = ROOT.join("_site")
  REPO = "https://github.com/metanorma/standoc-models"
  BASE = "standoc"

  # Hub grammar file name for a flavour — most use <flavor>.rnc; legacy
  # exceptions kept for gem-path compatibility.
  LEGACY_GRAMMAR = {
    "m3aawg" => "m3d.rnc",
    "gb" => "gbstandard.rnc",
    "iso" => "isostandard.rnc",
  }.freeze

  SUBMODULES = [
    ["basicdoc-models", "BasicDocument — the document core every layer builds on"],
    ["relaton-models", "Relaton — the bibliographic reference models (CC/ISO 6900)"],
    ["metanorma-requirements-models", "Requirements — the requirement/modelling vocabulary"],
  ].freeze

  def h(str)
    str.to_s
       .gsub("&", "&amp;")
       .gsub("<", "&lt;")
       .gsub(">", "&gt;")
       .gsub('"', "&quot;")
  end

  def flavors
    File.readlines(ROOT.join("flavors.txt"), chomp: true)
        .map(&:strip).reject(&:empty?)
  end

  def description_for(flavor)
    readme = ROOT.join(flavor, "README.adoc")
    return nil unless File.file?(readme)

    File.read(readme)[/^Information models for (.+?), based on/, 1]
  end

  def load_flavor(flavor, index)
    views = Dir[ROOT.join("#{flavor}/models/*.lml")].sort
    cards = views.map do |path|
      body = File.read(path)
      stem = File.basename(path, ".lml")
      Card.new(
        flavor: flavor,
        name: stem,
        title: body[/^\s*title\s+['"]([^'"]+)['"]/, 1] || stem.tr("_", " "),
        caption: body[/^\s*caption\s+['"]([^'"]+)['"]/, 1],
        image: "#{flavor}/images/#{stem}.png",
        github_url: "#{REPO}/blob/main/#{flavor}/models/#{stem}.lml",
      )
    end

    kind = flavor == BASE ? :base : :flavor
    grammar = File.exist?(ROOT.join("grammars", "#{flavor}.rnc")) ? "#{flavor}.rnc" : LEGACY_GRAMMAR[flavor]

    Flavor.new(
      name: flavor,
      code: flavor.upcase,
      kind: kind,
      clause: kind == :base ? "2" : "3.#{index}",
      description: description_for(flavor),
      cards: cards,
      model_files: Dir[ROOT.join("#{flavor}/models/**/*.lml")].size,
      grammar: grammar,
      legacy_grammar: grammar != "#{flavor}.rnc",
    )
  end

  def load_flavors
    seq = 0
    flavors.map do |f|
      seq += 1 unless f == BASE
      load_flavor(f, seq)
    end
  end

  def render(template, locals)
    erb = ERB.new(File.read(SITE.join("templates", "#{template}.html.erb")), trim_mode: "-")
    b = binding
    locals.each { |k, v| b.local_variable_set(k, v) }
    erb.result(b)
  end

  def build!
    FileUtils.rm_rf(OUT)
    FileUtils.mkdir_p(OUT)

    mods = load_flavors
    base = mods.find { |m| m.name == BASE }
    overlays = mods.reject { |m| m.kind == :base }
    total_cards = mods.sum { |m| m.cards.size }
    total_models = mods.sum(&:model_files)

    File.write(OUT.join("index.html"), render("layout",
                   title: "StanDoc Models — the standard document, modelled",
                   body: render("index", mods: mods, base: base, overlays: overlays,
                                total_cards: total_cards, total_models: total_models)))

    mods.each do |mod|
      next if mod.cards.empty?

      File.write(OUT.join("#{mod.name}.html"), render("layout",
                     title: "#{mod.code} — StanDoc Models",
                     body: render("flavor", mod: mod, mods: mods)))
      # Committed diagrams so the catalogue stands alone before the LXR
      # SPA artifacts are overlaid at deploy time.
      src = ROOT.join(mod.name, "images")
      if Dir.exist?(src)
        FileUtils.mkdir_p(OUT.join(mod.name))
        FileUtils.cp_r(src, OUT.join(mod.name, "images"))
      end
    end

    FileUtils.cp_r(SITE.join("assets"), OUT.join("assets"))
    puts "site: #{mods.size} modules, #{total_cards} cards -> #{OUT}"
  end
end

StandocSite.build! if $PROGRAM_NAME == __FILE__
