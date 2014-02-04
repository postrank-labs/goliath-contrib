require 'goliath/contrib/plugin/statsd_plugin'
require 'goliath/contrib/rack/statsd_logger'

module Goliath
  module Contrib

    #
    # Send metrics to a statsd server. 
    #
    class StatsdAgent
      DEFAULT_HOST = '127.0.0.1' unless defined?(DEFAULT_HOST)
      DEFAULT_PORT = 8125        unless defined?(DEFAULT_PORT)
      DEFAULT_FRAC = 1.0         unless defined?(DEFAULT_FRAC)

      attr_reader   :prefix
      attr_reader   :port
      attr_reader   :host
      attr_accessor :logger

      # @param prefix [String]        prepended to all metrics this agent dispatches.
      # @param logger [Log4R::Logger] The logger
      # @param host   [String]        statsd hostname
      # @param port   [Integer]       statsd port number
      #
      # @return [Goliath::Contrib::Plugins::StatsdAgent] the statsd sender
      def initialize(prefix, host=nil, port=nil)
        @prefix = prefix
        @host   = host   || DEFAULT_HOST
        @port   = port   || DEFAULT_PORT
      end

      # Count an event.
      #
      # @param [String]  metric        the name of the metric (the agent's prefix, if any, will be prepended before sending)
      # @param [Integer] count         the number of new events to register
      # @param [Float]   sampling_frac if you are only recording some of the events, indicate the fraction here and statsd will take care of the rest
      #
      # @example
      #   FSF = 0.001
      #   # only record one fluxion event per thousand
      #   statsd_agent.count('hemiconducer.fluxions', 1, FSF) if (rand < FSF)
      #
      def count(metric, val=1, sampling_frac=nil)
        handle = metric_handle(metric)
        if sampling_frac && (rand < sampling_frac.to_F)
          send_to_statsd "#{handle}:#{val}|c|@#{sampling_frac}"
        else
          send_to_statsd "#{handle}:#{val}|c"
        end
      end

      # Report on the timing of an event -- a web request, perhaps.
      #
      # @param [String]  metric        the name` of the metric (the agent's prefix, if any, will be prepended before sending)
      # @param [Float]   val           the duration to record, in milliseconds
      #
      def timing(metric, val)
        handle = metric_handle(metric)
        send_to_statsd "#{handle}:#{val}|ms"
      end

    protected

      # @return [String] a dot-separated confection of the app-wide prefix and this metric's segments
      def metric_handle(metric=[])
        [@prefix, metric].flatten.reject{|x| x.to_s.empty? }.join(".")
      end

      # actually dispatch the metric
      def send_to_statsd(metric)
        @logger.debug{ "#{self.class} #{prefix} sending #{metric} to #{@host}:#{@port}" }
        socket.send_datagram metric, @host, @port
      end

      # @return [EM::Connection] The actual sender
      def socket
        return @socket if @socket
        @logger.info{ "#{self.class} #{prefix} opening connection to #{@host}:#{@port}" }
        @socket = EventMachine::open_datagram_socket('', 0, EventMachine::Connection)
      end

    end
  end
end
