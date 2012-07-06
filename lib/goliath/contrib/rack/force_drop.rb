module Goliath
  module Contrib
    module Rack

      # Middleware to simulate dropping a connection.
      #
      # * if the force_drop       env var is given, close the connection as soon as possible
      # * if the force_drop_after env var is given, close the connection late (after all following middlewares have happened)
      #
      # @example drop the connection immediately (see examples/test_rig.rb):
      #   time curl 'http://localhost:9000/?_force_drop=true'
      #   => curl: (52) Empty reply from server
      #   real  0m0.027s        user    0m0.008s        sys     0m0.005s
      #
      # @example drop the connection with no response after waiting one second; the delay is provided by the `ForceDelay` middleware in `_drop_after` mode:
      #   time curl 'http://localhost:9000/?_drop_after=true&_delay=1'
      #   => curl: (52) Empty reply from server
      #   real  0m1.111s        user    0m0.008s        sys     0m0.005s
      #
      class ForceDrop
        include Goliath::Rack::AsyncMiddleware

        def call(env)
          return super unless env[:force_drop].to_s == 'true'

          env.logger.info "Forcing dropped connection"
          env.stream_close
          [0, {}, {}]
        end

        def post_process(env, status, headers, body)
          return super unless env[:force_drop_after].to_s == 'true'

          env.logger.info "Forcing dropped connection (after having run through other warez)"
          env.stream_close
          [0, {}, {}]
        end

      end
    end
  end
end
