module Goliath
  module Contrib
    module Rack

      # if force_status, force_headers or force_body env attributes are present,
      # blindly substitute the attribute's value, clobbering whatever was there.
      #
      # @example setting headers with a JSON post body
      #   curl -v -H "Content-Type: application/json" --data-ascii '{"_force_headers":{"X-Question":"What is brown and sticky"},"_force_body":{"answer":"a stick"}}' 'http://127.0.0.1:9001/'
      #   => {"answer":"a stick"}
      #
      # @example force a boring response body so ab doesn't whine about a varying response body size:
      #   ab -n 10000 -c 100  'http://localhost:9000/?_force_body=OK'
      #
      class ForceResponse
        include Goliath::Rack::AsyncMiddleware

        def post_process(env, status, headers, body)
          if (force_status  = env[:force_status])  then  status  = force_status.to_i ; end
          if (force_headers = env[:force_headers]) then  headers = force_headers     ; end
          if (force_body    = env[:force_body])    then  body    = force_body        ; end
          [status, headers, body]
        end

      end
    end
  end
end
