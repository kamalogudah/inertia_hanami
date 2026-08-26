# frozen_string_literal: true

module InertiaHanami
  # Prop wrapper classes controlling how individual props are resolved and
  # included in the Inertia response (partial reloads, deferred loading, etc).
  module Props
    # Base class for all prop wrappers. Built on Ruby's `Data`, so wrappers are
    # immutable value objects with structural equality and no ActiveSupport
    # dependency.
    class Base < Data
      def resolve
        block.call
      end
    end

    # A prop that is only included in the response when explicitly requested
    # by the client (via a partial reload).
    Optional = Base.define(:block)

    # A prop that is always included in the response, even during a partial
    # reload that would otherwise exclude it.
    Always = Base.define(:block)

    # A prop that is loaded in a subsequent request after the initial page
    # load, batched together by `group`.
    Defer = Base.define(:group, :block) do
      def initialize(block:, group: "default")
        super
      end
    end

    # A prop that is evaluated only once and cached by the client.
    Once = Base.define(:key, :fresh, :expires_in, :block) do
      def initialize(block:, key: nil, fresh: false, expires_in: nil)
        super
      end

      # Calculates the expiration timestamp in milliseconds.
      #
      # @return [Integer, nil] the expiration time as a Unix timestamp in milliseconds, or nil if no expiration
      def expires_at
        return unless expires_in

        ((Time.now + expires_in).to_f * 1_000).to_i
      end
    end

    # A prop whose value is merged with the existing client-side prop of the
    # same name, instead of replacing it outright.
    Merge = Base.define(:block, :deep_merge, :match_on) do
      def initialize(block:, deep_merge: false, match_on: nil)
        super
      end
    end
  end
end
