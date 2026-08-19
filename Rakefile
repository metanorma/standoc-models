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
# assert PNG magic bytes directly (metanorma/ci#302/#303). A pure-Ruby
# check has no file(1) dependency, so it runs on every OS.
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
