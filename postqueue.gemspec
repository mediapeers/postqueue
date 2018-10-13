lib = File.expand_path('lib', __dir__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)

Gem::Specification.new do |gem|
  gem.name    = "postqueue"
  gem.version = File.read("VERSION")
  gem.authors = %w(radiospiel)
  gem.email   = %w(radiospiel@open-lab.org)

  gem.summary     = "simplistic postgresql based queue with support for batching and idempotent operations"
  gem.description = "simplistic postgresql based queue with support for batching and idempotent operations"
  gem.homepage    = "https://github.com/mediapeers/postqueue"
  gem.license     = "MIT"

  gem.files       = Dir["**/*"].select { |d| d =~ %r{^(README|data/|ext/|lib/|spec/|test/)} }
  # gem.executables = [ "postqueue-worker" ]
  gem.executables = ["postqueue"]

  gem.add_development_dependency "pry", "~> 0.10"
  gem.add_development_dependency "pry-byebug"
  gem.add_development_dependency "rake", "~> 10.5.0"
  gem.add_development_dependency "rspec", "~> 3.5.0"
  gem.add_development_dependency "simplecov"

  gem.add_development_dependency "activerecord", "~> 4"
  gem.add_development_dependency "rubocop", "~> 0.49"
  gem.add_development_dependency "timecop", "~> 0.8"
  gem.add_dependency "pg", "~> 0", ">= 0.20"
  gem.add_dependency "simple-sql", "~> 0", ">= 0.3.3"
  gem.add_dependency "table_print"
end
