module Goliath
  module Contrib
    module Rack

      #
      # Force a timeout after given number of seconds
      #
      # ForceTimeout ensures your response takes *at most* N seconds. ForceDelay
      # ensures your response takes *at least* N seconds. To have a response
      # take *as-close-as-reasonable-to* N seconds, use an N-second ForceTimeout
      # with an (N+1)-second ForceDelay.
      #
      #
      # @example first call is 200 OK, second will error with 408 RequestTimeoutError (see examples/test_rig.rb):
      #   curl -v 'http://127.0.0.1:9000/?_force_timeout=1.0&_force_delay=0.5'
      #   => Headers: X-Resp-Delay: 0.5 / X-Resp-Randelay: 0.0 / X-Resp-Actual: 0.513401985168457 / X-Resp-Timeout: 1.0
      #   curl -v 'http://127.0.0.1:9000/?_force_timeout=1.0&_force_delay=2.0'
      #   => {"status":408,"error":"RequestTimeoutError","message":"Request exceeded 1.0 seconds"}
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
                headers.merge!('X-Resp-Timeout' => timeout.to_s)
                async_cb.call([status, headers, body])
              end
            end

            # timeout callback, executed by EM timer.
            # This will always fire, we just don't do anything if already handled.
            # If not handled elsewhere, mark as handled and raise an error
            EM.add_timer(timeout) do
              unless env[:force_timeout_complete]
                env[:force_timeout_complete] = true
                err = Goliath::Validation::RequestTimeoutError.new("Request exceeded #{timeout} seconds")
                async_cb.call(error_response(err, 'X-Resp-Timeout' => timeout.to_s))
              end
            end
          end

          status, headers, body = @app.call(env)

          if status == Goliath::Connection::AsyncResponse.first
            env[:force_timeout_complete] = true
          end
          [status, headers, body]
        end

      end
    end
  end
end
