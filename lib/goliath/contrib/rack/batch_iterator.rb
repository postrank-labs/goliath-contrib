class BatchIterator < EM::Synchrony::Iterator
  include Goliath::Rack::Validator

  DEFAULT_CONCURRENCY = 10 unless defined?(DEFAULT_CONCURRENCY)

  def initialize(env, batch_id, timeout, queries, concurrency=nil)
    concurrency ||= DEFAULT_CONCURRENCY
    @env          = env
    @batch_id     = batch_id
    @http_options = Hash.new
    @http_options[:inactivity_timeout] = timeout.to_s
    @http_options[:connect_timeout   ] = timeout.to_s
    #
    @results = {}
    @errors  = {}
    super queries, concurrency
  end

  def perform
    EM.synchrony do
      # first part of response
      EM.next_tick{ safely(@env){ response_preamble } }

      # rest of response
      each(
        proc{|(req_id, url), iter| safely(@env){
            p [url, @http_options]
            req = EM::HttpRequest.new(url, @http_options).aget
            req.callback{ safely(@env){ handle_result(req_id, req) ; iter.next } }
            req.errback{  safely(@env){ handle_error( req_id, req) ; iter.next } }
            @env.logger.debug [object_id, "request", req_id, req.req.uri.query].join("\t")
        } },
        # called at finish
        proc{ safely(@env){
          send_response_coda
          @env.chunked_stream_close
        } }
        )
    end
  end

protected

  # Called once before iterator starts, but after stream has initialized.
  # Use this for any initial portion of the payload
  def response_preamble
  end

  # Called on successful response -- saves the result.
  #
  # This method is called if our *HttpRequest* succeeded -- even if it's a 404
  # or 503 or whatever back from the client, that's a successful response
  #
  # @param [String]      req_id The arbitrary id for this request, chosen by the caller
  # @param [HttpRequest] req    The successful HttpRequest connection object
  #
  def handle_result req_id, req
    @results[req_id] = [
      req.response_header.http_status,
      req.response_header,
      req.response.to_s.chomp
    ]
  end

  # Called on each unsuccessful response -- save a summary of the error
  #
  # @param [String]      req_id The arbitrary id for this request, chosen by the caller
  # @param [HttpRequest] req    The unsuccessful HttpRequest connection object
  #
  # This method is called if our *HttpRequest* succeeded -- even if it's a 404
  # or 503 or whatever back from the client, that's a successful response, and
  # this method is not called.
  #
  # The error messages for HttpRequest are often (always?) blank -- a bug is
  # pending to fix this.
  def handle_error req_id, req
    err = req.error.to_s
    err = 'no_response' if err.empty?
    @errors[req_id]  = [Goliath::Validation::BadRequestError.status_code, {}, err]
  end

  #
  # A helpful hash of statistics about the batch
  #
  def stats
    {
      :duration           => (Time.now.to_f - @env[:start_time]).round(3),
      :queries            => (@results.length + @errors.length),
      :concurrency        => concurrency,
      :inactivity_timeout => @http_options[:inactivity_timeout],
      :connect_timeout    => @http_options[:connect_timeout],
      :batch_id           => @batch_id,
    }
  end

  # Called after all responses have completed, before the stream is closed.
  def send_response_coda
  end
end

#
# Makes a JSON response in batches. The preamble opens a hash with field
# "results". Each successful response is delivered in a single line, as a single
# chunked-transfer chunk, mapping the req_id (as a json string) to a hash with
# the response http status code and the JSON-encoded body. NOTE: the body is
# JSON-encoded from whatever it was! If it was already JSON, you will need to
# call JSON.parse again on the body.
#
# Errors are accumulated as they roll in. After all requests complete, this
# dumps out a row with helpful stats, and the hash of errback results.
#
#     {
#     "results":{
#     "13348":{"status":200,"body":"{\"trstrank\":4.9,\"user_id\":13348,\"screen_name\":\"Scobleizer\",\"tq\":99}"},
#     "18686296":{"status":200,"body":"{\"trstrank\":0.65,\"user_id\":18686296,\"screen_name\":\"bryanconnor\",\"tq\":99}"},
#     "_count":2},
#     "stats":{"duration":3.593,"queries":100,"concurrency":15,"inactivity_timeout":2.0,"connect_timeout":1.0},
#     "errors":{"1554031":{"error":"no_response"}}
#     }
#
#
class JsonBatchIterator < BatchIterator
  # Begin text for a hash with field "results".
  def response_preamble
    super
    send "{"
    send '"results":{'
  end

  # Deliver successful response -- sends a single line (as a single
  # chunked-transfer chunk) mapping the request ID to a hash holding the http
  # status code and the JSON-encoded body.
  #
  # NOTE: the body is JSON-encoded, whatever it was! If it was already JSON,
  # you will need to call JSON.parse again on the body.
  def handle_result(req_id, req)
    status, headers, body = super
    send_key  = MultiJson.dump(req_id)
    send_body = MultiJson.dump(status: status, body: body)
    send send_key, ":", send_body, ','
  end

  # Unsuccessful responses are delivered in the response_coda, so we don't need
  # to do anything but let `super` record the response
  def handle_error req_id, req
    super
  end

  # Dumps a row with helpful stats and the hash of errback results.
  def send_response_coda
    super
    send '"_":{}},' # end results hash
    send '"stats":',  MultiJson.dump(stats), ','
    send '"errors":', MultiJson.dump(@errors)
    send '}'
  end

  def send *parts
    @env.chunked_stream_send("#{parts.join}\n")
  end
end

# outputs results, one per line, tab-separated. Each line is
#
#     EVENT     req_id    status   body\n
#
# No changes are made to the body except to scrub it for internal CR, LF and TAB
#
class TsvBatchIterator < BatchIterator
  def handle_result req_id, req
    status, headers, body = super
    send_tsv '_r', req_id, status, body
  end

  def handle_error req_id, req
    status, headers, body = super
    send_tsv '_e', req_id, status, body
  end

  def send_response_coda
    super
    send_tsv '_s',  '', '', stats.values.join("\t")
  end

  def send_tsv(event, req_id, status, body)
    body = body.to_s.gsub(/[\r\n]+/, " ")
    line = [event, req_id, status, body].join("\t")
    @env.chunked_stream_send("#{line}\n")
  end
end
