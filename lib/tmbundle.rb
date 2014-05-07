require 'pathname'
require 'thor'

class TMBundle < Thor
  desc 'edit PARTIAL_NAME', 'Edit an installed bundle (name will be matched against PARTIAL_NAME)'
  def edit partial_name
    matches = installed_bundles.select do |bundle|
      bundle.name =~ /^#{partial_name}/i
    end

    if matches.size > 1
      puts "please be more specific:"
      matches.each_with_index {|m,i| puts " #{i+1}) #{m.name}"}
      return false
    end

    if matches.empty?
      puts "nothing found"
      return false
    end

    bundle = matches.first
    mate bundle.path
  end

  desc 'update', 'Update installed bundles'
  def update
    require 'thread'
    signals = Queue.new
    trap('INT') { signals << :int }

    updated = []
    skipped = []
    errored = []

    installed_bundles[0..4].each do |bundle|
      within bundle do
        if not(File.exist?('./.git'))
          puts "------> Skipping #{bundle.name} (not a Git repo, delta bundle?)"
          skipped << bundle
          next
        end

        puts "------> Updating #{bundle.name}..."
        system *%w[git pull --ff-only]
        success = $? == 0
        updated << bundle if success
        errored << bundle unless success
        puts
        (puts 'Exiting…'; exit) if signals.pop == :int until signals.empty?
      end
    end

    puts
    puts
    puts '------> Summary'
    puts
    puts "Skipped (#{skipped.size})\n- #{skipped.map(&:name).join("\n- ")}\n\n" if skipped.any?
    puts "Updated (#{updated.size})\n- #{updated.map(&:name).join("\n- ")}\n\n" if updated.any?
    puts "Errored (#{errored.size})\n- #{errored.map(&:name).join("\n- ")}\n\n" if errored.any?
  end

  desc 'install', 'Install a bundle from GitHub'
  def install name
    name = BundleName.new(name)
    install_path = bundles_dir.join(name.install_name).to_s
    system('git', 'clone', name.git_url, install_path)
  end

  class BundleName
    def initialize(name)
      @name = name
    end

    attr_reader :name
    private :name

    def install_name
      File.basename(name.gsub(/([\.\-_]tmbundle)?$/i, '.tmbundle'))
    end

    def repo_name
      name+'.tmbundle' unless name =~ /([\.\-_]tmbundle)$/i
    end

    def git_url
      "https://github.com/#{repo_name}.git"
    end
  end

  private

  def within bundle
    Dir.chdir bundle.path do
      yield
    end
  end

  def installed_bundles
    @installed_bundles ||= Dir[bundles_dir.join('*').to_s].map {|path| Bundle.new(path)}
  end

  def bundles_dir
    @bundles_dir ||= Pathname('~/Library/Application Support/Avian/Bundles').expand_path
  end

  class Bundle < Struct.new(:path)
    def name
      @name ||= File.basename(path, '.tmbundle')
    end
  end

  def mate *args
    exec 'mate', *args
  end
end

