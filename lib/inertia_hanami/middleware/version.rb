# frozen_string_literal: true

require "rack/request"

module InertiaHanami
  module Middleware
    # Plain Rack middleware implementing the Inertia protocol's asset
    # versioning handshake: on a GET Inertia request whose X-Inertia-Version
    # header doesn't match the server's configured version, respond with a
    # 409 + X-Inertia-Location (empty body) instead of calling downstream,
    # so the client performs a full browser visit and picks up new assets.
    class Version
      def initialize(app)
        @app = app
      end

      def call(env)
        request_context = RequestContext.new(env)

        if stale?(env, request_context)
          request = Rack::Request.new(env)
          return [409, { "X-Inertia-Location" => request.url }, [""]]
        end

        @app.call(env)
      end

      private

      def stale?(env, request_context)
        env["REQUEST_METHOD"] == "GET" &&
          request_context.inertia? &&
          request_context.version != Hanami.app["inertia.config"].version
      end
    end
  end
end
