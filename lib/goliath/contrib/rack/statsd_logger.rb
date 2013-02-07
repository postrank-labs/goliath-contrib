module Goliath
  module Contrib
    module Rack

      # Record the duration and count of all requests, report them to statsd
      #
      # @example a dhardbaord view on the log data
      #   # assumes graphite dashboard on 33.33.33.30
      #   http://33.33.33.30:5100/render/?from=-10minutes&width=960&height=720&colorList=67A9CF,91CF60,1A9850,FC8D59,D73027&bgcolor=FFFFF0&fgcolor=808080&target=stats.timers.statsd_demo.dur.root.mean_90&target=stats.timers.statsd_demo.dur.200.mean_90&target=stats.timers.statsd_demo.dur.200.upper_90&target=group(stats.timers.statsd_demo.dur.[0-9]*.mean_90)&target=group(stats.timers.statsd_demo.dur.[0-6]*.count)
      #
      class StatsdLogger
        include Goliath::Rack::AsyncMiddleware

        attr_reader :statsd

        # @param [Goliath::Application] app
        # @param [Goliath::Contrib::StatsdAgent] statsd Sends metrics to the statsd server
        def initialize(app, statsd)
          @statsd = statsd
          super(app)
        end

        def call(env)
          statsd.count [:req, 'route', dotted_route(env)]
          super(env)
        end

        def post_process(env, status, headers, body)
          ms_elapsed = (1000 * (Time.now.to_f - env[:start_time].to_f))
          statsd.timing([:dur, 'route', dotted_route(env)], ms_elapsed)
          statsd.timing([:dur, status],            ms_elapsed)
          [status, headers, body]
        end

        def dotted_route(env)
          path = env['PATH_INFO'].gsub(%r{^/}, '')
          (path == '') ? 'root' : path.gsub(%r{/}, '.')
        end
      end
    end
  end
end
