module Goliath

  module Validation ; class InjectedError < Error ; end ; end
  
  module Contrib
    module Rack

      # if either the '_fail_pre' or '_fail_post' parameter is given, raise an error
      # The parameter's value (as an integer) becomes the response code
      class ForceFault
        include Goliath::Rack::AsyncMiddleware

        def call(env)
          if code = env.params['_fault']
            raise Goliath::Validation::InjectedError.new(code.to_i, "Injected middleware fault #{code}")
          end
          super
        end

        def post_process(env, *)
          if code = env.params['_fault_post']
            raise Goliath::Validation::InjectedError.new(code.to_i, "Injected middleware fault #{code} (after response was composed)")
          end
          super
        end

      end

    end
  end
end
