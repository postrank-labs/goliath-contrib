module Goliath
  module Contrib

    module CaptureHeaders
      # save client headers (only) into env[:client_headers]
      def on_headers(env, headers)
        env[:client_headers] = headers
        super(env, headers) if defined?(super)
      end
    end

    module Rack

      #
      # Add headers showing the request's parameters, path, headers and method
      #
      # You must also include Goliath::Contrib::CaptureHeaders in your responder class
      #
      # @example
      #   class AwesomeService < Goliath::API
      #     include Goliath::Contrib::CaptureHeaders
      #     use     Goliath::Contrib::Rack::Diagnostics
      class Diagnostics
        include Goliath::Rack::AsyncMiddleware

        def request_diagnostics(env)
          client_headers = env[:client_headers] or env.logger.info("Please 'include Goliath::Contrib::CaptureHeaders' in your API class")
          req_params  = env.params.collect{|param|     param.join(": ") }
          req_headers = client_headers.collect{|param| param.join(": ") }
          {
            "X-Next"        => @app.class.name,
            "X-Req-Params"  => req_params.join("|"),
            "X-Req-Path"    => env[Goliath::Request::REQUEST_PATH],
            "X-Req-Headers" => req_headers.join("|"),
            "X-Req-Method"  => env[Goliath::Request::REQUEST_METHOD]}
        end

        def post_process env, status, headers, body
          headers.merge!(request_diagnostics(env))
          [status, headers, body]
        end
      end

    end
  end
end
