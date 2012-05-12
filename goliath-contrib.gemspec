# -*- encoding: utf-8 -*-

require File.expand_path('../lib/goliath/contrib', __FILE__)

# require './lib/goliath/contrib'

Gem::Specification.new do |gem|
  gem.authors       = ["goliath-io"]
  gem.email         = ["goliath-io@googlegroups.com"]

  gem.homepage      = "https://github.com/postrank-labs/goliath-contrib"
  gem.description   = "Contributed Goliath middleware, plugins, and utilities"
  gem.summary       = gem.description

  gem.files         = `git ls-files`.split($\)
  gem.executables   = gem.files.grep(%r{^bin/}).map{ |f| File.basename(f) }
  gem.test_files    = gem.files.grep(%r{^(test|spec|features)/})
  gem.name          = "goliath-contrib"
  gem.require_paths = ["lib"]
  gem.version       = Goliath::Contrib::VERSION

  gem.add_dependency 'goliath'  
end
