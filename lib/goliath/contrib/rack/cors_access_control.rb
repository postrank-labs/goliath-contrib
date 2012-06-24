# Settings.define :acc, :default => nil

module Goliath
  module Contrib
    module Rack

      #
      # Provides Cross-Origin Resource Sharing headers, a superior alternative to
      # JSON-p responses.
      #
      # This implementation is **entirely promiscuous**: it says "yep, that is
      # allowed" to _any_ request. The more circumspect user should investigate
      # https://github.com/cyu/rack-cors/
      #
      # @example
      #   # A request with method OPTIONS and Access-Control-Request-Headers set
      #   # to 'Content-Type,X-Zibit' would receive headers
      #   {
      #     'Access-Control-Allow-Origin'   => '*',
      #     'Access-Control-Allow-Methods'  => 'POST, GET, OPTIONS',
      #     'Access-Control-Max-Age'        => '172800',
      #     'Access-Control-Expose-Headers' => 'X-Error-Message,X-Error-Detail,X-RateLimit-Requests,X-RateLimit-MaxRequests',
      #     'Access-Control-Allow-Headers'  => 'Content-Type,X-Zibit'
      #   }
      #
      #
      class CorsAccessControl
        include Goliath::Rack::AsyncMiddleware

        DEFAULT_CORS_HEADERS = {
          'Access-Control-Allow-Origin'   => '*',
          'Access-Control-Expose-Headers' => 'X-Error-Message,X-Error-Detail,X-RateLimit-Requests,X-RateLimit-MaxRequests',
          'Access-Control-Max-Age'        => '172800',
          'Access-Control-Allow-Methods'  => 'POST, GET, OPTIONS',
          'Access-Control-Allow-Headers'  => 'X-Requested-With,Content-Type'
        }

        def access_control_headers(env)
          cors_headers = DEFAULT_CORS_HEADERS.dup
          client_headers_to_approve = env['HTTP_ACCESS_CONTROL_REQUEST_HEADERS'].to_s.gsub(/[^\w\-\,]+/,'')
          cors_headers['Access-Control-Allow-Headers'] += ",#{client_headers_to_approve}" if not client_headers_to_approve.empty?
          cors_headers
        end

        def call(env, *args)
          if env[Goliath::Request::REQUEST_METHOD] == 'OPTIONS'
            return [200, access_control_headers(env), []]
          end
          super(env)
        end

        def post_process(env, status, headers, body)
          headers['Access-Control-Allow-Origin'] = '*'
          [status, headers, body]
        end
      end

    end
  end
end
