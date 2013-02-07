module Goliath
  module Contrib
    module Rack

      # Place static values fron initialize into the env on each request
      class StaticConfigurator
        include Goliath::Rack::AsyncMiddleware

        def initialize(app, env_vars)
          @extra_env_vars = env_vars
          super(app)
        end

        def call(env,*)
          env.merge!(@extra_env_vars)
          super
        end
      end

      #
      #
      # @example imposes a timeout if 'rapid_timeout' param is present
      #   class RapidServiceOrYour408Back < Goliath::API
      #     use Goliath::Rack::Params
      #     use ConfigurateFromParams, [:timeout], 'rapid'
      #     use Goliath::Contrib::Rack::ForceTimeout
      #   end
      #
      class ConfigurateFromParams
        include Goliath::Rack::AsyncMiddleware

        def initialize(app, param_keys, slug='')
          @extra_env_vars = param_keys.inject({}){|acc,el| acc[el.to_sym] = [slug, el].join("_") ; acc }
          super(app)
        end

        def call(env,*)
          @extra_env_vars.each do |env_key, param_key|
            # env.logger.info [env_key, param_key, env.params[param_key]]
            env[env_key] ||= env.params.delete(param_key)
          end
          super
        end
      end

    end
  end
end
