# frozen_string_literal: true

module InertiaHanami
  # Include-able into `Hanami::Action` subclasses to speak the Inertia
  # protocol: skips Hanami's automatic view rendering for Inertia XHR
  # requests, renders the Inertia page envelope, accumulates shared props,
  # and handles the external-redirect (409 + X-Inertia-Location) case.
  #
  # Follows Hanami's own composition idiom (`include Inertia::Action`)
  # rather than requiring a subclass of a framework-specific base class.
  module Action
    # Session key used to stash validation errors across a redirect, mirroring
    # inertia-rails' `session[:inertia_errors]`. Cleared as soon as it's read
    # into the next response's `errors` prop.
    INERTIA_ERRORS_SESSION_KEY = "inertia_errors"

    def self.included(action_class)
      super

      action_class.extend(ClassMethods)
      action_class.include(InstanceMethods)

      action_class.append_before do |req, res|
        @inertia_context[:request] = req
        @inertia_context[:response] = res
      end

      share_errors_and_flash(action_class)
    end

    # Auto-shared on every request: `errors` (from the session, stashed via
    # `share_inertia_errors`) and `flash` (from Hanami's flash). Registered
    # before any `inertia_share` calls in the including class's own body, so
    # those can override either key. No-ops entirely when the app hasn't
    # enabled sessions (`session_enabled?` defaults to `false` on
    # `Hanami::Action`).
    def self.share_errors_and_flash(action_class)
      action_class.inertia_share do
        next {} unless session_enabled?

        { errors: inertia_errors_prop, flash: inertia_flash_prop }.compact
      end
    end
    private_class_method :share_errors_and_flash

    # Class-level `inertia_share` macro, inherited down subclasses.
    module ClassMethods
      def inertia_shared_props
        inherited_inertia_shared_props.merge(@inertia_shared_props ||= {})
      end

      def inertia_shared_blocks
        inherited_inertia_shared_blocks + (@inertia_shared_blocks ||= [])
      end

      def inertia_share(**props, &block)
        (@inertia_shared_props ||= {}).merge!(props)
        (@inertia_shared_blocks ||= []) << block if block
      end

      private

      def inherited_inertia_shared_props
        superclass.respond_to?(:inertia_shared_props) ? superclass.inertia_shared_props : {}
      end

      def inherited_inertia_shared_blocks
        superclass.respond_to?(:inertia_shared_blocks) ? superclass.inertia_shared_blocks : []
      end
    end

    # Instance-level Inertia API mixed into the including action class.
    module InstanceMethods
      # Runs before the object is frozen (Hanami::Action freezes instances at
      # the end of #initialize), so @inertia_context can hold a mutable Hash
      # to stash the request/response for later use by frozen instance methods.
      def initialize(...)
        @inertia_context = {}
        super
      end

      def auto_render?(res)
        return false if RequestContext.new(res.env).inertia?

        super
      end

      def inertia_share(**props, &block)
        instance_props = (@inertia_context[:instance_shared_props] ||= {})
        instance_props.merge!(props)
        (@inertia_context[:instance_shared_blocks] ||= []) << block if block
      end

      def inertia_render(component, props: {}, url: nil, version: nil,
                         encrypt_history: false, clear_history: false)
        Renderer.new(
          request: @inertia_context[:request],
          response: @inertia_context[:response],
          component: component,
          props: inertia_collected_props.merge(props),
          url: url,
          version: version || Hanami.app["inertia.config"].version,
          encrypt_history: encrypt_history,
          clear_history: clear_history
        ).render
      end

      def inertia_location(url)
        request = @inertia_context[:request]
        response = @inertia_context[:response]

        if RequestContext.new(request.env).inertia?
          response.headers["X-Inertia-Location"] = url
          halt(409)
        else
          response.redirect_to(url)
        end
      end

      # Stashes `errors` in the session so they surface as the `errors` prop
      # on the next request's Inertia page (e.g. after a validation failure
      # redirect). Analogous to inertia-rails' `redirect_to ..., inertia: {
      # errors: ... }`.
      def share_inertia_errors(errors)
        hash = errors.respond_to?(:to_h) ? errors.to_h : errors
        @inertia_context[:request].session[INERTIA_ERRORS_SESSION_KEY] = hash
      end

      private

      def inertia_collected_props
        props = self.class.inertia_shared_props.dup
        self.class.inertia_shared_blocks.each { |block| props.merge!(instance_exec(&block)) }
        props.merge!(@inertia_context[:instance_shared_props]) if @inertia_context[:instance_shared_props]
        (@inertia_context[:instance_shared_blocks] || []).each { |block| props.merge!(instance_exec(&block)) }
        props
      end

      # Reads and clears any errors stashed via `share_inertia_errors`, so
      # they're delivered exactly once. Falls back to an empty hash when
      # `always_include_errors_hash` is enabled, or is omitted (nil) entirely
      # otherwise.
      def inertia_errors_prop
        stashed = @inertia_context[:request].session.delete(INERTIA_ERRORS_SESSION_KEY)
        return Props::Always.new(block: -> { stashed }) if stashed

        return nil unless Hanami.app["inertia.config"].always_include_errors_hash

        Props::Always.new(block: -> { {} })
      end

      # Shares the current request's flash messages, when there are any.
      def inertia_flash_prop
        flash = @inertia_context[:response].flash.now
        return nil if flash.empty?

        Props::Always.new(block: -> { flash })
      end
    end
  end
end
