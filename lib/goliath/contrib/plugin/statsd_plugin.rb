module Goliath
  module Contrib
    module Plugin

      # Initializes the statsd agent and dispatches regular metrics about this server
      #
      # Often enjoyed in the company of the Goliath::Contrib::Rack::StatsdLogger middleware.
      #
      # @example
      #   plugin Goliath::Contrib::Plugin::StatsdPlugin, Goliath::Contrib::StatsdAgent.new('my_app', '33.33.33.30')
      #
      # A URL something like this will show you the state of the reactor latency:
      #
      #     http://33.33.33.30:5100/render/?from=-12minutes
      #       &width=960&height=720
      #       &yMin=&yMax=
      #       &colorList=67A9CF,91CF60,1A9850,FC8D59,D73027
      #       &bgcolor=FFFFF0
      #       &fgcolor=808080
      #       &target=stats.timers.statsd_demo.reactor.latency.lower
      #       &target=stats.timers.statsd_demo.reactor.latency.mean_90
      #       &target=stats.timers.statsd_demo.reactor.latency.upper_90
      #       &target=stats.timers.statsd_demo.reactor.latency.upper
      #
      class StatsdPlugin
        attr_reader :agent

        # Called by the framework to initialize the plugin
        #
        # @param port [Integer] Unused
        # @param global_config [Hash] The server configuration data
        # @param status [Hash] A status hash
        # @param logger [Log4R::Logger] The logger
        # @return [Goliath::Contrib::Plugins::StatsdPlugin] An instance of the Goliath::Contrib::Plugins::StatsdPlugin plugin
        def initialize(port, global_config, status, logger)
          @logger = logger
          @config = global_config
        end

        # Called automatically to start the plugin
        #
        # @example
        #   plugin Goliath::Contrib::Plugin::StatsdPlugin, Goliath::Contrib::StatsdAgent.new('my_app')
        def run(agent)
          @agent = agent
          agent.logger ||= @logger
          register_latency_timer
        end

        # Send canary packets to the statsd reporting on this server's latency every 1 second
        def register_latency_timer
          @logger.info{ "#{self.class} registering timer for reactor latency" }
          @last   = Time.now.to_f
          #
          EM.add_periodic_timer(1.0) do
            agent.timing 'reactor.latency', (Time.now.to_f - @last)
            @last = Time.now.to_f
          end
        end
      end
    end
  end
end
