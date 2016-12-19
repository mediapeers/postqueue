module VersionNumberTracker
  extend self

  # Update version entry in version_file to new_version. When new_version is nil,
  # the new version is calculated based on the old version.
  def update_version(new_version)
    new_version ||= bumped_version
    update_version_file(new_version)
  end

  def root
    File.expand_path("../../", __FILE__)
  end

  def version_file
    candidates = Dir.glob("#{root}/lib/**/version.rb")
    if candidates.length != 1
      raise "Cannot determine version.rb file. There must be exactly one of those below #{root}/lib"
    end
    candidates.first
  end

  def gem_name
    candidates = Dir.glob("#{root}/*.gemspec")
    if candidates.length != 1
      raise "Cannot determine *.gemspec file. There must be exactly one in #{root}"
    end
    File.basename(candidates.first).sub(/\.gemspec\z/, "")
  end

  private

  VERSION_PATTERN = /VERSION\s*=\s*['"](\d+\.\d+\.\d+)['"]/

  def update_version_file(new_version)
    old_version_file = File.read(version_file)

    new_version = "VERSION = \"#{new_version}\""
    new_version_file_content = old_version_file.gsub(VERSION_PATTERN, new_version)

    File.open(version_file, "w") { |file| file.puts new_version_file_content }
  end

  def bumped_version
    old_version_number = read_version
    old = old_version_number.split(".")
    current = old[0..-2] << old[-1].next
    current.join(".")
  end

  public

  # return current version as read from version_file
  def read_version
    hits = File.read(version_file).scan(VERSION_PATTERN).first
    raise "Can't detect verson string in #{version_file}" unless hits
    hits.first
  end
end

def sys?(cmd)
  system cmd
  $?.exitstatus == 0
end

namespace :prerelease do
  namespace :git do
    task :is_on_master do
      current_branch = `git branch 2> /dev/null`.split("\n").select { |line| line =~ /\A\* / }.first
      current_branch = current_branch[2..-1] if current_branch
      next if current_branch == "master"

      Bundler.ui.error("You must be on master to release the gem, but you are on #{current_branch.inspect}.")
      exit 1
    end

    # see http://stackoverflow.com/questions/2657935/checking-for-a-dirty-index-or-untracked-files-with-git
    task :is_clean do
      next if sys?("git diff-index --quiet --cached HEAD") && sys?("git diff-files --quiet")

      Bundler.ui.error("Working directory is not clean: commit or rollback your changes!")
      exit 1
    end

    task :is_uptodate do
      sh "git pull"
    end
  end

  task prerequisites: %w(git:is_on_master git:is_clean git:is_uptodate)

  task :bump_version do
    VersionNumberTracker.update_version ENV["VERSION"]
  end

  task :commit do
    version = VersionNumberTracker.read_version
    version_file = VersionNumberTracker.version_file
    gem_name = VersionNumberTracker.gem_name
    sh("git commit -m \"bump #{gem_name} to v#{version}\" #{version_file}")
  end

  task all: %w(prerequisites bump_version commit)
end

desc "Prerelease tasks: increment version number and commit"
task prerelease: "prerelease:all"
