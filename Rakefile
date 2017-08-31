require "bundler/gem_tasks"
require "rspec/core/rake_task"

RSpec::Core::RakeTask.new(:spec)

task :default do
  sh "rspec"
  sh "POSTQUEUE_TABLE_NAME=postqueue.spec_queue rspec"
end

load "tasks/prerelease.rake"
