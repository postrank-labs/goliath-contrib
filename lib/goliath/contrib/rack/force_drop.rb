module Goliath
  module Contrib
    module Rack

      # Middleware to simulate dropping a connection.
      #
      # * if the _drop       env var is given, close the connection as soon as possible
      # * if the _drop_after env var is given, close the connection late (after all following middlewares have happened)
      #
      # @example drop the connection immediately
      #   curl 'http://localhost:9000/?_drop=true'
      #
      # @example wait one second then drop the connection with no response (note: `_drop_after`, not `_drop`)
      #   curl 'http://localhost:9000/?_drop_after=true&_delay=1'
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
