require "rspec/core/rake_task"

RSpec::Core::RakeTask.new(:spec)

task default: :spec

desc "release a new development gem version"
task :release do
  sh "scripts/release.rb"
end

desc "release a new stable gem version"
task "release:stable" do
  sh "BRANCH=stable scripts/release.rb"
end
