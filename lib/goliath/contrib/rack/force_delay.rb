module Goliath
  module Contrib

    module Rack

      # Delays response for `_delay + (0 to _randelay)` seconds, as given by the
      # `_delay` and `_randelay` request parameters. Delays longer than 5
      # seconds are clamped to 5 seconds.
      #
      # This delay is non-blocking -- *other* requests may proceed in turn --
      # though naturally the call chain for this response doesn't proceed until
      # the delay is complete.
      #
      # Information about the delay is added to the response headers for your enjoyment.
      #
      # @example simulate a highly variable response time (min 0.5, max 1.5 seconds)
      #   curl -v 'http://127.0.0.1:9000/?_delay=0.5&_randelay=1.0'
      #
      class ForceDelay
        include Goliath::Rack::AsyncMiddleware

        def post_process(env, status, headers, body)
          delay    = env.params['_delay'].to_f
          randelay = env.params['_randelay'].to_f
          #
          if (delay > 0) || (randelay > 0)
            be_sleepy(delay, randelay)
            actual = (Time.now.to_f - env[:start_time])
            headers.merge!( 'X-Resp-Delay' => delay.to_s, 'X-Resp-Randelay' => randelay.to_s, 'X-Resp-Actual' => actual.to_s )
            body.merge!( :_delay_ms => delay, :randelay_ms => randelay, :_actual_ms => actual )
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
