module Goliath
  module Contrib

    module Rack

      # Delays response for `delay + (0 to randelay)` additional seconds after
      # the app's response.
      #
      # This delay is non-blocking -- *other* requests may proceed in turn --
      # though naturally the call chain for this response doesn't proceed until
      # the delay is complete.
      #
      # ForceDelay ensures your response takes *at least* N seconds. Force
      # Timeout ensures your response takes *at most* N seconds. To have a
      # response take *as-close-as-reasonable-to* N seconds, use an N-second
      # ForceTimeout with an (N+1)-second ForceDelay.
      #
      # The `force_delay` and `force_randelay` env variables specify the delay;
      # values are clamped to be less than 5 seconds. Information about the
      # delay is added to the response headers for your enjoyment.
      #
      # @example simulate a highly variable (0.5-1.5 sec) response time (see examples/test_rig.rb):
      #   curl -v 'http://127.0.0.1:9000/?_force_delay=0.5&_force_randelay=1.0'
      #   => Headers: X-Resp-Delay: 0.5 / X-Resp-Randelay: 1.0 / X-Resp-Actual: 0.90205979347229
      #
      class ForceDelay
        include Goliath::Rack::AsyncMiddleware

        def post_process(env, status, headers, body)
          delay    = env[:force_delay].to_f
          randelay = env[:force_randelay].to_f
          #
          if (delay > 0) || (randelay > 0)
            be_sleepy(delay, randelay)
            actual = (Time.now.to_f - env[:start_time])
            headers.merge!( 'X-Resp-Delay' => delay.to_s, 'X-Resp-Randelay' => randelay.to_s, 'X-Resp-Actual' => actual.to_s )
          end
          [status, headers, body]
        end

        # sleep time limited to 5 seconds
        def be_sleepy(delay, randelay)
          total  = delay + (randelay * rand)
          total  = [0, [total, 5].min].max # clamp
          #
          EM::Synchrony.sleep(total)
        end
      end
    end
  end
end
