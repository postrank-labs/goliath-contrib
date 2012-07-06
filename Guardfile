# -*- ruby -*-

format = 'progress' # 'doc' for more verbose, 'progress' for less
tags   = %w[ ]
guard 'rspec', :version => 2, :cli => "--format #{format} #{ tags.map{|tag| "--tag #{tag}"}.join(' ')  }" do
  watch(%r{^spec/.+_spec\.rb$})
  watch(%r{^lib/(.+)\.rb$})           { |m| "spec/#{m[1]}_spec.rb"  }
  watch(%r{^examples/(.+)\.rb$})      { |m| "spec/integration/#{m[1]}_spec.rb" }

  watch('spec/spec_helper.rb')         { 'spec' }
  watch(/spec\/support\/(.+)\.rb/)     { 'spec' }
end

group :docs do
  guard 'yard' do
    watch(%r{app/.+\.rb})
    watch(%r{lib/.+\.rb})
    watch(%r{ext/.+\.c})
  end
end
