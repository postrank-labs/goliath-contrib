module Goliath
  module Contrib
    module Rack

      # if _status, _headers or _body are given, blindly substitute their
      # value, clobbering whatever was there.
      #
      # If you are going to use _headers you probably need to use a JSON post body.
      #
      # @example setting headers with a JSON post body
      #   curl -v -H "Content-Type: application/json" --data-ascii '{"_headers":{"X-Question":"What is brown and sticky"},"_body":{"answer":"a stick"}}' 'http://127.0.0.1:9001/'
      #
      # @example forcing a boring response body so ab doesn't whine about a varying response body size
      #   ab -n 10000 -c 100  'http://localhost:9000/?_delay=0.4&_randelay=0.01&_body=OK'
      #
      class ForceResponse
        include Goliath::Rack::AsyncMiddleware

        def post_process(env, status, headers, body)
          if (force_status  = env.params['_status'])  then  status  = force_status.to_i ; end
          if (force_headers = env.params['_headers']) then  headers = force_headers     ; end
          if (force_body    = env.params['_body'])    then  body    = force_body        ; end
          [status, headers, body]
        end

      end
    end
  end
end
