module Goliath
  module Contrib
    module Rack

      # Rescue validation errors in the app just as you do
      # in middleware
      #
      # Place this as early as possible in the request chain, but after the rendering.
      #
      # @example For JSON-encoded responses, good and bad:
      #   class AwesomeApp < Goliath::API
      #     use Goliath::Rack::DefaultMimeType           # cleanup accepted media types
      #     use Goliath::Rack::Render, 'json'            # auto-negotiate response format
      #     use Goliath::Contrib::Rack::HandleExceptions # turn raised errors into HTTP responses
      #     use Goliath::Rack::Params                    # parse & merge query and body parameters
      #     # ... awesomeness goes here ...
      #   end
      #
      class HandleExceptions
        include Goliath::Rack::AsyncMiddleware
        include Goliath::Rack::Validator

        def call(env)
          safely(env){ super }
        end
      end
    end
  end

  module Rack
    module Validator
      module_function

      # @param status_code [Integer] HTTP status code for this error.
      # @param msg [String] message to inject into the response body.
      # @param headers [Hash] Response headers to preserve in an error response;
      #   (the Content-Length header, if any, is removed)
      def validation_error(status_code, msg, headers={})
        err_class = Goliath::HTTP_ERRORS[status_code.to_i]
        err = err_class ? err_class.new(msg) : Goliath::Validation::Error.new(status_code, msg)
        error_response(err, headers)
      end

      # @param err [Goliath::Validation::Error] error to describe in response
      # @param headers [Hash] Response headers to preserve in an error response;
      #   (the Content-Length header, if any, is removed)
      def error_response(err, headers={})
        headers.merge!({
            'X-Error-Message' => err.class.default_message,
            'X-Error-Detail'  => err.message,
          })
        headers.delete('Content-Length')
        body    = {
          status:  err.status_code,
          error:   err.class.to_s.gsub(/.*::/,""),
          message: err.message,
        }
        [err.status_code, headers, body]
      end

    end
  end
end
