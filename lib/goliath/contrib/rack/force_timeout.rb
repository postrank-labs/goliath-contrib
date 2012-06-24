module Goliath
  module Contrib
    module Rack

      #
      # Force a timeout after given number of seconds
      #
      class ForceTimeout
        include Goliath::Rack::Validator

        # @param app [Proc] The application
        # @return [Goliath::Rack::AsyncMiddleware]
        def initialize(app)
          @app     = app
        end

        # @param env [Goliath::Env] The goliath environment
        # @return [Array] The [status_code, headers, body] tuple
        def call(env, *args)
          timeout = [0.0, [env[:force_timeout].to_f, 10.0].min].max

          if (timeout != 0.0)
            async_cb = env['async.callback']
            env[:force_timeout_complete] = false

            # Normal callback, executed by downstream middleware
            # If not handled elsewhere, mark as handled and pass along unchanged
            env['async.callback'] = Proc.new do |status, headers, body|
              unless env[:force_timeout_complete]
                env[:force_timeout_complete] = true
                async_cb.call([status, headers, body])
              end
            end

            # timeout callback, executed by EM timer.
            # This will always fire, we just don't do anything if already handled.
            # If not handled elsewhere, mark as handled and raise an error
            EM.add_timer(timeout) do
              async_cb.call(safely(env){ handle_timeout(env, timeout) })
            end
          end

          status, headers, body = @app.call(env)

          if status == Goliath::Connection::AsyncResponse.first
            env[:force_timeout_complete] = true
          end
          [status, headers, body]
        end

        def handle_timeout(env, timeout)
          unless env[:force_timeout_complete]
            env[:force_timeout_complete] = true
            raise Goliath::Validation::RequestTimeoutError.new("Request exceeded #{timeout} seconds")
          end
        end
      end
    end
  end
end
