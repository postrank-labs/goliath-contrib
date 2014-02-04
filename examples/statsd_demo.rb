#!/usr/bin/env ruby

# See notes in examples/test_rig for preconditions and usage

require File.expand_path('test_rig', File.dirname(__FILE__))
require 'goliath/contrib/statsd_agent'

class StatsdDemo < TestRig
  statsd_agent = Goliath::Contrib::StatsdAgent.new('statsd_demo', '33.33.33.30')
  plugin Goliath::Contrib::Plugin::StatsdPlugin, statsd_agent
  use    Goliath::Contrib::Rack::StatsdLogger,   statsd_agent
  
  self.set_middleware!

end
