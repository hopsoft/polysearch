# frozen_string_literal: true

require File.expand_path("../lib/polysearch/version", __FILE__)

Gem::Specification.new do |gem|
  gem.name = "polysearch"
  gem.license = "MIT"
  gem.version = Polysearch::VERSION
  gem.authors = ["Nathan Hopkins"]
  gem.email = ["natehop@gmail.com"]
  gem.homepage = "https://github.com/hopsoft/polysearch"
  gem.summary = "Simplified polymorphic full text + similarity search based on postgres"

  gem.metadata = {
    "homepage_uri" => gem.homepage,
    "source_code_uri" => gem.homepage
  }

  gem.files = Dir["app/**/*", "lib/**/*", "bin/*", "[A-Z]*"]
  gem.test_files = Dir["test/**/*.rb"]

  gem.add_dependency "rails", ">= 6.0"

  gem.add_development_dependency "bundler", "~> 2.0"
  gem.add_development_dependency "rake"
  gem.add_development_dependency "standardrb"
  gem.add_development_dependency "magic_frozen_string_literal"
end
