#!/usr/bin/env ruby
# $:.unshift File.expand_path('../lib', File.dirname(__FILE__))

require 'goliath'
require 'goliath/contrib/rack/diagnostics'
require 'goliath/contrib/rack/force_delay'
require 'goliath/contrib/rack/force_drop'
require 'goliath/contrib/rack/force_fault'
require 'goliath/contrib/rack/force_response'
require 'goliath/contrib/rack/handle_exceptions'

#
# A test endpoint allowing fault injection, variable delay, or a response forced by the client.
#
# * with `_delay`               parameter, delay the given length of time before responding
# * with `_drop`/`_drop_post`   parameter, drop connection with no response
# * with `_fail`/`_fail_post`   parameter, raise an error of the given type (eg `_fail_pre=400` causes a BadRequestError)
# * with `_status`, `_headers`, or `_body' parameter, replace the given component directly.
#
# @example set headers
#   curl -v -H "Content-Type: application/json" --data-ascii '{"_headers":{"X-Question":"What is brown and sticky"},"_body":{"answer":"a stick"}}' 'http://127.0.0.1:9001/'
#
# @example drop connection
#   curl -v 'http://127.0.0.1:9000/?_drop_pre=true'
#
# @example delay for 3 seconds
#   curl -v 'http://127.0.0.1:9000/?_delay=2'
#
# @example delay for 3 seconds, then drop the connection (using drop_after)
#   curl -v 'http://127.0.0.1:9000/?_delay=2&_drop_post=true'
#
class TestRig < Goliath::API
  include Goliath::Contrib::CaptureHeaders

  def self.set_middleware!
    use Goliath::Rack::Tracer                    # log trace statistics
    use Goliath::Rack::Params                    # parse & merge query and body parameters
    use Goliath::Rack::DefaultMimeType           # cleanup accepted media types
    use Goliath::Rack::Render, 'json'            # auto-negotiate response format

    use Goliath::Contrib::Rack::HandleExceptions # turn raised errors into HTTP responses
    use Goliath::Contrib::Rack::ForceDrop        # drop connection if 'drop' param
    use Goliath::Contrib::Rack::ForceFault       # raise an error if 'fail' param
    use Goliath::Contrib::Rack::ForceResponse    # replace with given value if '_status', '_headers' or '_body' is returned
    use Goliath::Contrib::Rack::ForceDelay       # force response to take at least (_delay +/- _randelay) seconds
    use Goliath::Contrib::Rack::Diagnostics      # summarize the request in the response headers
  end
  self.set_middleware!

  def response(env)
    [200, { 'X-API' => self.class.name }, {}]
  end
end
