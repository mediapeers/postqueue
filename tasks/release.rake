GEM_ROOT = File.expand_path('../../', __FILE__)

module VersionNumberTracker
  extend self

  VERSION_FILE = Dir.glob("#{GEM_ROOT}/lib/**/*.version.rb")
  raise VERSION_FILE.inspect 

  VERSION_PATTERN = /VERSION = '(\d+\.\d+\.\d+)'/

  def update_version_file(new_version)
    old_version_file = File.read(VERSION_FILE)

    new_version = "VERSION = '#{new_version}'"
    new_version_file_content = old_version_file.gsub(VERSION_PATTERN, new_version)

    File.open(VERSION_FILE, 'w') { |file| file.puts new_version_file_content }
  end

  def bumped_version
    old_version_number = read_version
    old = old_version_number.split('.')
    current = old[0..-2] << old[-1].next
    new_version = current.join('.')
  end

  public

  # Update version to new_version. WHen new_version is nil, the new version is 
  # determined automatically.
  def update_version(new_version)
    new_version ||= bumped_version
    update_version_file(new_version)
  end

  # return current version as read from VERSION_FILE
  def read_version
    read_version = nil 
    File.read(VERSION_FILE).gsub(VERSION_PATTERN) do |_|
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
  namespace :prerequisites do
    task :chdir do
      Dir.chdir(GEM_ROOT)
    end

    task :git_is_on_master do
      current_branch = `git name-rev --name-only HEAD`.chomp
      next if current_branch == 'master'

      Die! "You must be on master to release the gem, but you are on #{current_branch.inspect}."
     end

     # see http://stackoverflow.com/questions/2657935/checking-for-a-dirty-index-or-untracked-files-with-git
     task :git_is_clean do
       next if Sys?('git diff-index --quiet --cached HEAD') && Sys?('git diff-files --quiet')
       Die!("Working directory is not clean: commit or rollback your changes!")
     end

     task :git_is_uptodate do
       sh 'git pull'
     end
  end

  desc 'Check release prerequisites'
  task :prerequisites => %w(prerequisites:chdir prerequisites:git_is_on_master prerequisites:git_is_clean prerequisites:git_is_uptodate)

  desc 'Bump version number'
  task :bump_version do
    VersionNumberTracker.update_version ENV['VERSION']
  end

  desc 'Build gem file'
  task :build do
    sh('gem build mpx-tracer.gemspec')
    sh('mv mpx-tracer-*.gem pkg')
  end

  desc 'Commit changed version files'
  task :commit do
    version = VersionNumberTracker.read_version
    sh("git commit -m \"bump tracer to v#{version}\" #{VERSION_FILE}")
    sh("git tag -a v#{version} -m \"Tag\"")
  end

  desc 'Push code and tags'
  task :push do
    sh('git push --follow-tags origin master')
  end

  desc 'Push Gem to gemfury'
  task :push_to_gemfury do
    version = VersionNumberTracker.read_version
    gem_path = "pkg/mpx-tracer-#{version}.gem"
    sh("bundle exec fury push #{gem_path} --as mediapeers")
  end

  task default: [
    'prerequisites',
    'bump_version',
    'build',
    'commit',
    'push',
    'push_to_gemfury'
  ]
end

desc "Clean, build, commit and push"
task release: "release:default"
