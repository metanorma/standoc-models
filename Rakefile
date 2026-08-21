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

  abort "parity: #{errors.size} issue(s):\n  #{errors.join("\n  ")}" unless errors.empty?
  puts "parity: OK (#{flavors.size} flavours, #{flavors.sum { |f| Dir["#{f}/models/*.lml"].size }} views)"
end

desc "Build the model catalogue site into _site/ (deployed by deploy.yml)"
task :site do
  require_relative "site/generate"
  StandocSite.build!
end
