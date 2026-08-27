# frozen_string_literal: true

require "rack/request"
require "uri"

module InertiaHanami
  module Middleware
    # Plain Rack middleware implementing the Inertia protocol's redirect
    # mechanics:
    #
    # - 301/302 redirects issued in response to a PUT/PATCH/DELETE request are
    #   rewritten to 303, so the client's follow-up GET doesn't resubmit the
    #   original request body.
    # - Redirects to an external origin are rewritten to a 409 response with
    #   an X-Inertia-Location header instead of a normal redirect, since
    #   Inertia's XHR-driven visits can't follow cross-origin redirects
    #   themselves; the client reads that header and performs a full
    #   browser visit instead.
    #
    # Both rewrites only apply to Inertia requests (X-Inertia header) —
    # ordinary browser navigations are left untouched.
    class Redirects
      REWRITTEN_STATUSES = [301, 302].freeze
      BODY_RESUBMITTING_METHODS = %w[PUT PATCH DELETE].freeze

      def initialize(app)
        @app = app
      end

      def call(env)
        status, headers, body = @app.call(env)

        request_context = RequestContext.new(env)
        return [status, headers, body] unless request_context.inertia?

        location = headers["Location"] || headers["location"]
        return [status, headers, body] unless redirect?(status) && location

        if external?(env, location)
          return [409, { "X-Inertia-Location" => location }, [""]]
        end

        if REWRITTEN_STATUSES.include?(status) && BODY_RESUBMITTING_METHODS.include?(env["REQUEST_METHOD"])
          status = 303
        end

        [status, headers, body]
      end

      private

      def redirect?(status)
        status.to_i.between?(300, 399)
      end

      def external?(env, location)
        target = URI.parse(location)
        return false if target.host.nil?

        request = Rack::Request.new(env)
        target.scheme != request.scheme || target.host != request.host || target.port != request.port
      rescue URI::InvalidURIError
        false
      end
    end
  end
end
