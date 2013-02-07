#!/usr/bin/env ruby

require 'postrank-uri'
require 'set'
require 'goliath'
require 'em-synchrony/em-http'

require 'goliath/contrib/rack/configurator'
require 'goliath/contrib/rack/diagnostics'
require 'goliath/contrib/rack/handle_exceptions'

require 'gorillib/object/blank'
require 'goliath/contrib/rack/handle_exceptions'
require 'goliath/contrib/rack/batch_iterator'

require 'rack/mime'
Rack::Mime::MIME_TYPES['.tsv'] = "text/tsv"

# The examples use the test_rig from goliath-contrib:
#
#     bundle exec ./examples/test_rig.rb       -s -p 9000 -e production &
#     bundle exec ./examples/son_of_a_batch.rb -s -p 9004 -e production
#
# It gives us a target that can simulate a variable delay, dropped connections, server faults, and so forth.
#
# In the first example, son_of_a_batch is called with the default batch timeout
# of 2.0sec and concurrency 10.  If you run the curl command given below, you
# will see that the responses roll in as they are received:
#
# * req 0 delay 1.5  -- the last `OK` response sent, even though it was the first dispatched.
# * req 1 delay 2.3  -- causes an `ETIMEDOUT` error on the son_of_a_batch side
# * req 2 delay 1.02 -- arrives after the next two requests -- they are launched at effectively the same time
# * req 3 delay 1    -- first among the `OK`'s
# * req 4 delay 1    -- second among the `OK`'s
# * req 5 delay 4.0  -- causes an `ETIMEDOUT` error on the son_of_a_batch side
#
# @example a simple get batch (many params against one host)
#   curl -v 'http://localhost:9004/batch.json?url_base=http%3A%2F%2Flocalhost%3A9000%2F%3F_force_delay%3D&url_vals=1.5,2.3,1.02,1,1,4.0'
#   =>
#       {
#       "results":\{
#       "3":{"status":200,"body":"{\"_delay_ms\":1.0,\"_randelay_ms\":0.0,\"_actual_ms\":1.0118811130523682,\"_delay_start\":1340566341.449735}"},
#       "4":{"status":200,"body":"{\"_delay_ms\":1.0,\"_randelay_ms\":0.0,\"_actual_ms\":1.008415937423706,\"_delay_start\":1340566341.4538581}"},
#       "2":{"status":200,"body":"{\"_delay_ms\":1.02,\"_randelay_ms\":0.0,\"_actual_ms\":1.1126141548156738,\"_delay_start\":1340566341.441438}"},
#       "0":{"status":200,"body":"{\"_delay_ms\":1.5,\"_randelay_ms\":0.0,\"_actual_ms\":1.5765349864959717,\"_delay_start\":1340566341.434098}"},
#       "_":{}},
#       "stats":{"duration":2.013,"queries":6,"concurrency":10,"inactivity_timeout":"2.0","connect_timeout":"2.0","batch_id":36},
#       "errors":{"1":[400,{},"Errno::ETIMEDOUT"],"5":[400,{},"Errno::ETIMEDOUT"]}
#       }
# __________________________________________________________________________
#
# In the second example, son_of_a_batch is called using a JSON post body, but still using the simple `url_vals` iterator.
#
# 1.5,2.3,0.3&_force_fault=503,0.3&_force_drop=true,1.02,1,1,4.0
# * req 0 delay 1.5  -- the next-to-last `OK` response sent, even though it was the first dispatched.
# * req 1 delay 2.3  -- succeeds, because we increased the `batch_timeout`
# * req 2 delay 0.3 and _force_fault=503 -- returns immediately with a *successful* (to son_of_a_batch) 503 response.
# * req 3 delay 0.3 and _force_drop=true -- drops connection immediately, so it's an error (to son_of_a_batch) that it can't explain
# * req 4 delay 1.02 -- arrives after the next two requests -- they are launched at effectively the same time
# * req 5 delay 1    -- first among the `OK`'s
# * req 6 delay 1    -- second among the `OK`'s
# * req 7 delay 4.0  -- causes an `ETIMEDOUT` error on the son_of_a_batch side
#
# @example a get batch (JSON request)
#   curl -v -H "Content-Type: application/json" --data-ascii '{ "batch_timeout":2.5, "url_base":"http://localhost:9000/?_force_delay=", "url_vals":"1.5,2.3,0.3&_force_fault=503,0.3&_force_drop=true,1.02,1,1,4.0" }' 'http://localhost:9004/batch.json'
#   =>
#       {
#       "results":\{
#       "2":{"status":503,"body":"{\"status\":503,\"error\":\"ServiceUnavailableError\",\"message\":\"Injected middleware fault 503\"}"},
#       "5":{"status":200,"body":"{\"_delay_ms\":1.0,\"_randelay_ms\":0.0,\"_actual_ms\":1.011551856994629,\"_delay_start\":1340566961.8383281}"},
#       "6":{"status":200,"body":"{\"_delay_ms\":1.0,\"_randelay_ms\":0.0,\"_actual_ms\":1.0085508823394775,\"_delay_start\":1340566961.84186}"},
#       "4":{"status":200,"body":"{\"_delay_ms\":1.02,\"_randelay_ms\":0.0,\"_actual_ms\":1.107508897781372,\"_delay_start\":1340566961.834423}"},
#       "0":{"status":200,"body":"{\"_delay_ms\":1.5,\"_randelay_ms\":0.0,\"_actual_ms\":1.5890910625457764,\"_delay_start\":1340566961.807979}"},
#       "1":{"status":200,"body":"{\"_delay_ms\":2.3,\"_randelay_ms\":0.0,\"_actual_ms\":2.3053030967712402,\"_delay_start\":1340566961.821911}"},
#       "_":{}},
#       "stats":{"duration":2.516,"queries":8,"concurrency":10,"inactivity_timeout":"2.5","connect_timeout":"2.5","batch_id":37},
#       "errors":{"3":[400,{},"no_response"],"7":[400,{},"Errno::ETIMEDOUT"]}
#       }
#
# @example Arbitrary assemblage of URLs (all hosts must be whitelisted)
#
#   APIKEY=XXXXX # http://www.infochimps.com/documentation
#   curl -v -H "Content-Type: application/json" --data-ascii '{"urls":{
#         "food":"http://api.infochimps.com/social/network/tw/token/word_stats?_apikey='$APIKEY'&tok=food",
#         "drink":"http://api.infochimps.com/social/network/tw/token/word_stats?_apikey='$APIKEY'&tok=drink",
#         "sex":"http://api.infochimps.com/social/network/tw/token/word_stats?_apikey='$APIKEY'&tok=sex",
#         "bieber":"http://api.infochimps.com/social/network/tw/token/word_stats?_apikey='$APIKEY'&tok=bieber"
#       }' 'http://localhost:9004/batch.json'
#
# @example Using son of a batch to automate commandline data analysis. I won't try to justify this mode of work, but you might enjoy taking it apart to understand it:
#
#   APIKEY=XXXXX # http://www.infochimps.com/documentation
#   curl -v -H "Content-Type: application/json" --data-ascii '{"batch_timeout":1.9,"url_base":"http://api.infochimps.com/social/network/tw/token/word_stats?_apikey='$APIKEY'&tok=","url_vals":"bieber,cars,cats,shoes,java,love,money,sex"}' 'http://localhost:9004/batch.tsv' | grep '^_r' | ruby -rjson -ne 'raw_resp = $_.split("\t",4).last; resp = JSON.parse(raw_resp); puts [resp["tok"], resp["total_usages"]].join("\t")' | sort -nk2
#   =>
#     java        522351.0
#     cats        838706.0
#     cars       1150704.0
#     shoes      1623588.0
#     bieber     1700116.0
#     sex        3695956.0
#     money      9496697.0
#     love      64208941.0
#   # bieber is more popular than shoes, and love is stronger than money.
#
class SonOfABatch < Goliath::API
  include Goliath::Validation
  include Goliath::Contrib::CaptureHeaders
  use Goliath::Rack::Heartbeat                 # respond to /status with 200, OK (monitoring, etc)
  use Goliath::Rack::Tracer                    # log trace statistics
  use Goliath::Rack::DefaultMimeType           # cleanup accepted media types
  use Goliath::Rack::Render, 'json'            # auto-negotiate response format
  use Goliath::Contrib::Rack::HandleExceptions # turn raised errors into HTTP responses
  use Goliath::Rack::Params                    # parse & merge query and body parameters

  use Goliath::Contrib::Rack::Diagnostics      # summarize the request in the response headers

  HOST_WHITELIST = %w[ api.infochimps.com localhost 127.0.0.1 ].to_set unless defined?(HOST_WHITELIST)
  MIN_TIMEOUT =  2.0 unless defined?(MIN_TIMEOUT) # seconds
  MAX_TIMEOUT = 10.0 unless defined?(MAX_TIMEOUT) # seconds

  # Acceptable characters in a request ID
  IDENTIFIER_OR_NUM_RE = /\A[a-zA-Z0-9]\w*\z/ unless defined?(IDENTIFIER_OR_NUM_RE)

  def initialize
    super
    @next_batch_id = 0
  end

  def response(env)
    requestor =
      case
      when env['PATH_INFO'] =~ %r{/batch\.json$} then JsonBatchIterator
      when env['PATH_INFO'] =~ %r{/batch\.tsv$}  then TsvBatchIterator
      else raise NotAcceptableError, "Only .json and .tsv are supported for son_of_a_batch"
      end
    @next_batch_id += 1
    headers = {'X-Responder' => self.class.to_s, 'X-Sob-Timeout' => timeout.to_s }

    # launch the requests; response will stream back asynchronously
    requestor.new(env, @next_batch_id, timeout, queries).perform
    chunked_streaming_response(200, headers)
  end

protected

  # @return [nil, Float] time to wait for responses, or nil for no timeout. Clamped to MIN_TIMEOUT..MAX_TIMEOUT seconds
  def timeout
    timeout = params['batch_timeout'].to_f
    (timeout == 0) ? MAX_TIMEOUT : [MIN_TIMEOUT, [timeout, MAX_TIMEOUT].min].max
  end

  # Turn the raw params hash into actionable values.
  def queries
    urls, url_base, url_vals = params.values_at('urls', 'url_base', 'url_vals')

    if urls && urls.is_a?(Hash)
      # the outcome of a json-encoded POST body
      raw_queries = urls

    elsif url_base && url_vals
      # assemble queries by slapping each url_val on the end of url_base
      raise BadRequestError, "url_base must be a string" unless url_base.is_a?(String)
      raise BadRequestError, "url_vals must be an array or comma-delimited string" unless url_vals.is_a?(String) || url_vals.is_a?(Array)
      url_vals = url_vals.split(',') if url_vals.is_a?(String)
      #
      raw_queries = {}
      url_vals.each_with_index do |val, idx|
        raw_queries[idx] = "#{url_base}#{val}"
      end
    else
      raise BadRequestError, "Need either url_base and url_vals, or a JSON post body giving a hash of req_id:url pairs."
    end

    # make all the queries safe
    normalized_queries = {}
    raw_queries.each do |req_id, raw_q|
      raise BadRequestError, "Request IDs must be numbers or simple identifiers" unless (req_id.to_s =~ IDENTIFIER_OR_NUM_RE)
      norm_q = normalize_query(raw_q) or next
      normalized_queries[req_id.to_s] = norm_q
    end
    normalized_queries
  end

  # light safety and normalization for the url string
  def normalize_query url
    url = PostRank::URI.normalize(url) rescue nil
    return if url.blank?
    return if url.host.blank? || (! HOST_WHITELIST.include?(url.host))
    return unless (url.scheme == 'http')
    url
  end
end
