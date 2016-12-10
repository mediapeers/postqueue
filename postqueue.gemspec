lib = File.expand_path("../lib", __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)

require "postqueue/version"

Gem::Specification.new do |gem|
  gem.name    = "postqueue"
  gem.version = ::Postqueue::VERSION
  gem.authors = %w(radiospiel)
  gem.email   = %w(radiospiel@open-lab.org)

  gem.summary     = "a postgres based queue implementation"
  gem.description = "a postgres based queue implementation"
  gem.homepage    = "https://github.com/radiospiel/postqueue"
  gem.license     = "MIT"

  gem.files       = Dir["**/*"].select { |d| d =~ %r{^(README|data/|ext/|lib/|spec/|test/)} }
  # gem.executables = [ "postqueue-worker" ]

  gem.add_development_dependency "rspec", "~> 3.4.0"
  gem.add_development_dependency "pry", "~> 0.10"
  gem.add_development_dependency "pry-byebug"
  gem.add_development_dependency "rake", "~> 10.5.0"
  gem.add_development_dependency "simplecov", "~> 0.7.1"

  gem.add_development_dependency "activerecord", "~> 4"
  gem.add_development_dependency "timecop", "~> 0"
  gem.add_development_dependency "rubocop", "~> 0"
  gem.add_dependency "pg"
end
