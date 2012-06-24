module Goliath

  module Validation ; class InjectedError < Error ; end ; end
  
  module Contrib
    module Rack

      # if either the '_fail_pre' or '_fail_after' parameter is given, raise an error
      # The parameter's value (as an integer) becomes the response code
      class ForceFault
        include Goliath::Rack::AsyncMiddleware

        def call(env)
          if fault_code = env[:force_fault]
            raise Goliath::Validation::InjectedError.new(fault_code.to_i, "Injected middleware fault #{fault_code}")
          end
          super
        end

        def post_process(env, *)
          if fault_code = env[:force_fault_after]
            raise Goliath::Validation::InjectedError.new(fault_code.to_i, "Injected middleware fault #{fault_code} (after response was composed)")
          end
          super
        end

      end

    end
  end
end
