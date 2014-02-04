module Goliath

  module Validation ; class InjectedError < Error ; end ; end

  module Contrib
    module Rack

      # if either the 'force_fault' or 'force_fault_after' env attribute are
      # given, raise an error. The attribute's value (as an integer) becomes the
      # response code.
      #
      # @example simulate a 503 (see `examples/test_rig.rb`):
      #   curl -v 'http://127.0.0.1:9000/?_force_fault=503'
      #   => {"status":503,"error":"ServiceUnavailableError","message":"Injected middleware fault 503"}
      #
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
