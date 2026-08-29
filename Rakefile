# Unified build for the standoc-models monorepo. The flavour list comes
# from flavors.txt — the single source, also read by deploy.yml and the
# metanorma/ci path-filter job.

flavors = File.readlines("flavors.txt", chomp: true).map(&:strip).reject(&:empty?)

desc "Generate every flavour's model diagrams"
task default: flavors

flavors.each do |flavor|
  # Top-level models/*.lml are the rendered diagram views; subdirectories
  # are definition modules included by the views (deliberately not globbed).
  views = Dir["#{flavor}/models/*.lml"].sort.map do |lml|
    "#{flavor}/images/#{File.basename(lml, '.lml')}.png"
  end

  desc "Generate #{flavor} model diagrams"
  task flavor => views

  views.each do |png|
    lml = "#{flavor}/models/#{File.basename(png, '.png')}.lml"
    file png => lml do |t|
      mkdir_p File.dirname(t.name)
      sh "bundle", "exec", "lutaml-lml", "generate", t.source, "-o", t.name, "-t", "png"
    end
  end
end

# lutaml writes Graphviz dot source into .png paths when misflagged, so
# assert PNG magic bytes (metanorma/ci#302/#303).
PNG_MAGIC = "\x89PNG\r\n\x1a\n".b

desc "Assert every committed .png is a valid PNG"
task :verify do
  pngs = flavors.flat_map { |f| Dir["#{f}/images/*.png"] }.sort
  bad = pngs.reject { |p| File.binread(p, 8) == PNG_MAGIC }
  bad.each { |p| warn "ERROR: #{p} is not a valid PNG" }
  abort "verify: #{bad.size} of #{pngs.size} PNG(s) invalid" unless bad.empty?
  puts "verify: #{pngs.size} PNG file(s) OK"
end

desc "Remove generated diagrams"
task :clean do
  flavors.each { |f| Dir["#{f}/images/*.png"].each { |p| rm_f(p) } }
end

# "Any" is the wildcard extension point (e.g. UnitsML in MiscContainer).
BUILTIN_TYPES = %w[Integer Boolean Float Text String Date DateTime Any].freeze

# The grammar carries both passthrough concepts under one element name
# (standoc.rnc: `passthrough` block form + `passthrough_inline`), so the
# two same-named LML classes are a faithful model, not drift.
KNOWN_DUPLICATE_TYPES = %w[Passthrough].freeze

def lml_defined_types(path)
  File.read(path).scan(/^\s*(?:class|enum|data_type|primitive)\s+(\w+)/).flatten
end

desc "Lint LML semantics: file/type match, duplicate types, type resolution, view references"
task :lint do
  errors = []
  all_types = {}

  flavors.each do |flavor|
    defined = {}
    Dir["#{flavor}/models/**/*.lml"].sort.each do |f|
      types = lml_defined_types(f)
      # Definition modules (models/<package>/) must define their own stem;
      # top-level models/*.lml are views and may define anything.
      if f.match?(%r{\A#{flavor}/models/[^/]+/})
        stem = File.basename(f, ".lml")
        errors << "#{f}: file name is not a type defined in this file (defines: #{types.join(', ')})" unless types.include?(stem)
      end
      types.each { |t| (defined[t] ||= []) << f }
    end
    defined.each do |t, files|
      errors << "#{flavor}: duplicate type #{t}: #{files.join(', ')}" if files.size > 1 && !KNOWN_DUPLICATE_TYPES.include?(t)
    end
    all_types.merge!(defined) { |_k, a, _b| a }
  end

  # The basicdoc and relaton-models submodules close the type-resolution
  # set: flavour bib views extend RelBib types (TypedUri, DocumentIdentifier,
  # ...) and document views reference Basicdoc types (HierarchicalSection,
  # Image, ...) via collapsed cross-module boxes.
  %w[grammars/basicdoc-models grammars/relaton-models].each do |sub|
    Dir["#{sub}/**/models/**/*.lml"].sort.each do |f|
      lml_defined_types(f).each { |t| all_types[t] ||= [f] }
    end
  end

  # Attribute types must resolve somewhere in the repo or be builtins.
  flavors.each do |flavor|
    Dir["#{flavor}/models/**/*.lml"].sort.each do |f|
      File.foreach(f).with_index do |line, i|
        m = line.match(/^\s*[+#-]([a-zA-Z][\w-]*)\s*:\s*(.+)$/)
        next unless m

        raw = m[2].split("[")[0].split("{")[0].gsub(/<<[^>]*>>/, "").strip
        next if raw.empty? || raw.start_with?('"') || BUILTIN_TYPES.include?(raw)
        unless all_types.key?(raw)
          errors << "#{f}:#{i + 1}: attribute '#{m[1]}' references undefined type '#{raw}'"
        end
      end
    end
  end

  # View association endpoints must resolve (own include closure or a
  # cross-module reference rendered as a collapsed box).
  flavors.flat_map { |f| Dir["#{f}/models/*.lml"] }.sort.each do |v|
    File.foreach(v).with_index do |line, i|
      m = line.match(/^\s*(owner|member)\s+(\w+)/)
      next unless m

      unless all_types.key?(m[2])
        errors << "#{v}:#{i + 1}: association #{m[1]} '#{m[2]}' is not a known type"
      end
    end
  end

  abort "lint: #{errors.size} issue(s):\n  #{errors.join("\n  ")}" unless errors.empty?
  puts "lint: OK (#{all_types.size} types across #{flavors.size} flavours + basicdoc)"
end

desc "Assert layout parity: views, images, configs and module separation per flavour"
task :parity do
  errors = []

  flavors.each do |f|
    errors << "#{f}: not in flavors.txt order check" if f.strip.empty?
    errors << "#{f}: missing README.adoc" unless File.file?("#{f}/README.adoc")
    errors << "#{f}: missing build-config.yml" unless File.file?("#{f}/build-config.yml")

    views = Dir["#{f}/models/*.lml"].sort
    errors << "#{f}: no diagram views under models/*.lml" if views.empty?

    pngs = Dir["#{f}/images/*.png"].sort.map { |p| File.basename(p, ".png") }
    view_names = views.map { |v| File.basename(v, ".lml") }
    (view_names - pngs).each { |n| errors << "#{f}: view #{n}.lml has no committed PNG" }
    (pngs - view_names).each { |n| errors << "#{f}: orphan image #{n}.png (no view)" }

    # Definition modules under models/<package>/ must stay view-free.
    Dir["#{f}/models/*/*.lml"].each do |m|
      errors << "#{m}: definition module contains diagram (belongs at models/ top level)" if File.read(m) =~ /^\s*diagram\b/
    end
  end

  # 02 — Vocabulary parity: every mapped LML enum must equal its RNC
  # vocabulary (kebab-normalized). Adding a vocabulary = one entry here.
  vocab_parity = {
    "CSADocumentType" => ["documenttype", "grammars/csa.rnc"],
    "InputType" => ["InputType", "grammars/standoc.rnc"],
  }
  vocab_parity.each do |lml_enum, (rnc_def, rnc_path)|
    lml_vals = lml_enum_values(lml_enum)
    if lml_vals.nil?
      errors << "vocab parity: no LML enum #{lml_enum} found"
      next
    end
    rnc_vals = rnc_vocabulary(rnc_def, rnc_path)
    if rnc_vals.nil?
      errors << "vocab parity: #{rnc_path} has no definition #{rnc_def}"
      next
    end
    if lml_vals.uniq.sort != rnc_vals.uniq.sort
      errors << "vocab parity #{lml_enum} vs #{rnc_def}: LML-only=#{(lml_vals - rnc_vals).inspect} RNC-only=#{(rnc_vals - lml_vals).inspect}"
    end
  end

  abort "parity: #{errors.size} issue(s):\n  #{errors.join("\n  ")}" unless errors.empty?
  puts "parity: OK (#{flavors.size} flavours, #{flavors.sum { |f| Dir["#{f}/models/*.lml"].size }} views, #{vocab_parity.size} vocabularies)"
end

def lml_enum_values(name)
  Dir["*/models/**/*.lml"].sort.each do |path|
    vals = []
    depth = 0
    inside = false
    File.foreach(path) do |line|
      if !inside
        if line.match?(/^\s*enum #{name}\b/)
          inside = true
          depth = line.count("{") - line.count("}")
        end
        next
      end
      break if depth <= 0

      m = line.match(/^\s+([A-Za-z][\w-]*)\s*\{?\s*$/)
      vals << m[1] if m && m[1] != "definition"
      depth += line.count("{") - line.count("}")
    end
    return vals.map { |v| v.gsub(/([a-z\d])([A-Z])/, '\1-\2').tr("_", "-").downcase } if inside
  end
  nil
end

def rnc_vocabulary(def_name, path)
  body = File.readlines(path).reject { |l| l.lstrip.start_with?("##") }.join
  m = body.match(/^#{Regexp.escape(def_name)} =/)
  return nil unless m

  region = body[m.begin(0)..]
  rest = region[region.index("\n")..]
  stop = rest.match(/^[A-Za-z-][\w-]* =/)
  region = region[0, region.index("\n") + (stop ? stop.begin(0) : rest.size)] if stop
  region.scan(/"([\w.-]+)"/).flatten
end

desc "Build the model catalogue site into _site/ (deployed by deploy.yml)"
task :site do
  require_relative "site/generate"
  StandocSite.build!
end

desc "Validate examples/*.xml against the compiled standoc grammar"
task :"fixtures:xml" do
  sh "ruby", "tools/validate_xml.rb"
end

desc "Validate examples/*.yaml against the LML model"
task :"fixtures:yaml" do
  sh "ruby", "tools/validate_yaml.rb"
end

desc "Validate XML and YAML instance fixtures"
task fixtures: [:"fixtures:xml", :"fixtures:yaml"]

desc "Regenerate the JSON Schema from the LML models (freshness-gated in CI)"
task :schema do
  sh "python3", "tools/generate_schema.py"
end
