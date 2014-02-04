#!/usr/bin/env ruby
# $:.unshift File.expand_path('../lib', File.dirname(__FILE__))

require 'goliath'
require 'goliath/contrib/rack/configurator'
require 'goliath/contrib/rack/diagnostics'
require 'goliath/contrib/rack/force_delay'
require 'goliath/contrib/rack/force_drop'
require 'goliath/contrib/rack/force_fault'
require 'goliath/contrib/rack/force_response'
require 'goliath/contrib/rack/force_timeout'
require 'goliath/contrib/rack/handle_exceptions'

#
# A test endpoint allowing fault injection, variable delay, or a response forced
# by the client.  Besides being a nice demo of those middlewares, it's a useful
# test dummy for seeing how your SOA apps handle downstream failures.
#
# Launch with
#
#     bundle exec ./examples/test_rig.rb       -s -p 9000 -e development &
#
# If using it as a test rig, launch with `-e production`. The test rig acts on
# the following URL parameters:
#
# * `_force_timeout`                    -- raise an error if response takes longer than given time
# * `_force_delay`                      -- delay the given length of time before responding
# * `_force_drop`/`_force_drop_after`   -- drop connection immediately with no response
# * `_force_fail`/`_force_fail_after`   -- raise an error of the given type (eg `_force_fail_pre=400` causes a BadRequestError)
# * `_force_status`, `_force_headers`, or `_force_body' --  replace the given component directly.
#
# @example delay for 2 seconds:
#   curl -v 'http://127.0.0.1:9000/?_force_delay=2'
#   => Headers: X-Resp-Delay: 2.0 / X-Resp-Randelay: 0.0 / X-Resp-Actual: 2.003681182861328
#
# @example drop connection:
#   curl -v 'http://127.0.0.1:9000/?_force_drop=true'
#
# @example delay for 2 seconds, then drop the connection:
#   curl -v 'http://127.0.0.1:9000/?_force_delay=2&_force_drop_after=true'
#
# @example force timeout; first call is 200 OK, second will error with 408 RequestTimeoutError:
#   curl -v 'http://127.0.0.1:9000/?_force_timeout=1.0&_force_delay=0.5'
#   => Headers: X-Resp-Delay: 0.5 / X-Resp-Randelay: 0.0 / X-Resp-Actual: 0.513401985168457 / X-Resp-Timeout: 1.0
#   curl -v 'http://127.0.0.1:9000/?_force_timeout=1.0&_force_delay=2.0'
#   => {"status":408,"error":"RequestTimeoutError","message":"Request exceeded 1.0 seconds"}
#
# @example simulate a 503:
#   curl -v 'http://127.0.0.1:9000/?_force_fault=503'
#   => {"status":503,"error":"ServiceUnavailableError","message":"Injected middleware fault 503"}
#
# @example force-set headers and body:
#   curl -v -H "Content-Type: application/json" --data-ascii '{"_force_headers":{"X-Question":"What is brown and sticky"},"_force_body":{"answer":"a stick"}}' 'http://127.0.0.1:9001/'
#   => {"answer":"a stick"}
#
class TestRig < Goliath::API
  include Goliath::Contrib::CaptureHeaders

  def self.set_middleware!
    use Goliath::Rack::Heartbeat                 # respond to /status with 200, OK (monitoring, etc)
    use Goliath::Rack::Tracer                    # log trace statistics
    use Goliath::Rack::DefaultMimeType           # cleanup accepted media types
    use Goliath::Rack::Render, 'json'            # auto-negotiate response format
    use Goliath::Contrib::Rack::HandleExceptions # turn raised errors into HTTP responses
    use Goliath::Rack::Params                    # parse & merge query and body parameters

    # turn params like '_force_delay' into env vars :force_delay
    use(Goliath::Contrib::Rack::ConfigurateFromParams,
      [ :force_timeout, :force_drop, :force_drop_after, :force_fault, :force_fault_after,
        :force_status, :force_headers, :force_body, :force_delay, :force_randelay, ],)

    use Goliath::Contrib::Rack::ForceTimeout     # raise an error if response takes longer than given time
    use Goliath::Contrib::Rack::ForceDrop        # drop connection immediately with no response
    use Goliath::Contrib::Rack::ForceFault       # raise an error of the given type (eg `_force_fault=400` causes a BadRequestError)
    use Goliath::Contrib::Rack::ForceResponse    # replace as given by '_force_status', '_force_headers' or '_force_body'
    use Goliath::Contrib::Rack::ForceDelay       # force response to take at least (_force_delay + rand*_force_randelay) seconds
    use Goliath::Contrib::Rack::Diagnostics      # summarize the request in the response headers
  end
  self.set_middleware!

  def response(env)
    [200, { 'X-API' => self.class.name }, {}]
  end
end
