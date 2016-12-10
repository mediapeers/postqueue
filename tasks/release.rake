module VersionNumberTracker
  extend self

  # Update version entry in version_file to new_version. When new_version is nil,
  # the new version is calculated based on the old version.
  def update_version(new_version)
    new_version ||= bumped_version
    update_version_file(new_version)
  end

  private

  def root
    File.expand_path('../../', __FILE__)
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

  VERSION_PATTERN = /VERSION\s*=\s*'(\d+\.\d+\.\d+)'/

  def update_version_file(new_version)
    old_version_file = File.read(version_file)

    new_version = "VERSION = '#{new_version}'"
    new_version_file_content = old_version_file.gsub(VERSION_PATTERN, new_version)

    File.open(version_file, 'w') { |file| file.puts new_version_file_content }
  end

  def bumped_version
    old_version_number = read_version
    old = old_version_number.split('.')
    current = old[0..-2] << old[-1].next
    new_version = current.join('.')
  end

  # return current version as read from VERSION_FILE
  def read_version
    read_version = nil 
    File.read(version_file).gsub(VERSION_PATTERN) do |_|
      read_version = $1
    end
    read_version
  end
end

def Die!(msg)
  red_msg = "\e[31m#{msg}\e[0m"
  STDERR.puts red_msg
  exit 1
end

def Warn!(msg)
  yellow_msg = "\e[33m#{msg}\e[0m"
  STDERR.puts yellow_msg
end

def Sys?(cmd)
  system cmd
  $?.exitstatus == 0
end

namespace :release do
  namespace :git do
    task :is_on_master do
      current_branch = `git branch 2> /dev/null`.split("\n").select { |line| line =~ /\A\* / }.first
      current_branch = current_branch[2 .. -1] if current_branch
      next if current_branch == 'master'

      Die! "You must be on master to release the gem, but you are on #{current_branch.inspect}."
     end

     # see http://stackoverflow.com/questions/2657935/checking-for-a-dirty-index-or-untracked-files-with-git
     task :is_clean do
       next if Sys?('git diff-index --quiet --cached HEAD') && Sys?('git diff-files --quiet')
       Die!("Working directory is not clean: commit or rollback your changes!")
     end

     task :is_uptodate do
       sh 'git pull'
     end
  end

  task :prerequisites => %w(git:is_on_master git:is_clean git:is_uptodate)

  task :bump_version do
    VersionNumberTracker.update_version ENV['VERSION']
  end

  task :commit do
    version = VersionNumberTracker.read_version
    gem_name = VersionNumberTracker.gem_name
    sh("git commit -m \"bump #{gem_name} to v#{version}\" #{VERSION_FILE}")
    sh("git tag -a v#{version} -m \"Tag\"")
  end

  desc 'Prerelease tasks: increment version number and commit'
  task prerelease: %w(prerequisites bump_version commit)
end

task build: "release:prerelease"
