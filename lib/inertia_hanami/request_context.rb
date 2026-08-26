# frozen_string_literal: true

module InertiaHanami
  # Parses the Inertia protocol's request headers off a Rack env: detection
  # (X-Inertia), the asset version the client has cached (X-Inertia-Version),
  # and the partial-reload headers (X-Inertia-Partial-Component,
  # X-Inertia-Partial-Data, X-Inertia-Partial-Except, X-Inertia-Reset).
  #
  # Stays framework/Hanami-request free (plain Rack env in, plain values out)
  # so it can be constructed from anywhere a Rack env is available.
  class RequestContext
    def initialize(env)
      @env = env
    end

    def inertia?
      @env["HTTP_X_INERTIA"] == "true"
    end

    def version
      @env["HTTP_X_INERTIA_VERSION"]
    end

    def partial_component
      @env["HTTP_X_INERTIA_PARTIAL_COMPONENT"]
    end

    def partial?
      !partial_component.nil?
    end

    def partial_only
      split_header("HTTP_X_INERTIA_PARTIAL_DATA")
    end

    def partial_except
      split_header("HTTP_X_INERTIA_PARTIAL_EXCEPT")
    end

    def reset
      split_header("HTTP_X_INERTIA_RESET")
    end

    # Shaped to feed directly into ProtocolBuilder.new(partial: ...).
    def partial_params
      {
        component: partial_component,
        only: partial_only,
        except: partial_except,
        reset: reset
      }
    end

    private

    def split_header(key)
      value = @env[key]
      return [] if value.nil? || value.empty?

      value.split(",").map(&:strip).reject(&:empty?)
    end
  end
end
