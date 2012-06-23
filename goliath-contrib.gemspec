# -*- encoding: utf-8 -*-
$:.push File.expand_path("../lib", __FILE__)
require 'goliath/contrib/version'

Gem::Specification.new do |s|
  s.name        = "goliath-contrib"
  s.version     = Goliath::Contrib::VERSION

  s.authors     = ["goliath-io"]
  s.email       = ["goliath-io@googlegroups.com"]

  s.homepage    = "https://github.com/postrank-labs/goliath-contrib"
  s.summary     = "Contributed Goliath middleware, plugins, and utilities"
  s.description = s.summary

  s.required_ruby_version = '>=1.9.2'

  s.add_dependency 'goliath'

  s.add_development_dependency 'rspec', '>2.0'
  s.add_development_dependency 'nokogiri'
  s.add_development_dependency 'em-http-request', '>=1.0.0'
  s.add_development_dependency 'em-mongo', '~> 0.4.0'
  s.add_development_dependency 'rack-rewrite'
  s.add_development_dependency 'multipart_body'
  s.add_development_dependency 'amqp', '>=0.7.1'
  s.add_development_dependency 'em-websocket-client'

  s.add_development_dependency 'tilt', '>=1.2.2'
  s.add_development_dependency 'haml', '>=3.0.25'
  s.add_development_dependency 'yard'

  s.add_development_dependency 'guard'
  s.add_development_dependency 'guard-rspec'

  if RUBY_PLATFORM != 'java'
    s.add_development_dependency 'yajl-ruby'
    s.add_development_dependency 'bluecloth'
    s.add_development_dependency 'bson_ext'
  else
    s.add_development_dependency 'json-jruby'
    s.add_development_dependency 'maruku'
  end

  if RUBY_PLATFORM.include?('darwin')
    s.add_development_dependency 'growl', '~> 1.0.3'
    s.add_development_dependency 'rb-fsevent'
  end

  ignores = File.readlines(".gitignore").grep(/\S+/).map {|i| i.chomp }
  dotfiles = [".gemtest", ".gitignore", ".rspec", ".yardopts"]

  # s.files         = `git ls-files`.split($\)
  # s.executables   = s.files.grep(%r{^bin/}).map{ |f| File.basename(f) }
  # s.test_files    = s.files.grep(%r{^(test|spec|features)/})
  # s.require_paths = ["lib"]

  s.files = Dir["**/*"].reject {|f| File.directory?(f) || ignores.any? {|i| File.fnmatch(i, f) } } + dotfiles
  s.test_files = s.files.grep(/^spec\//)
  s.require_paths = ['lib']
end
