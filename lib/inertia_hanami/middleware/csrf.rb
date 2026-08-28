# frozen_string_literal: true

require "rack/request"
require "rack/utils"

module InertiaHanami
  module Middleware
    # Bridges Inertia's client-side CSRF handshake to Hanami's own
    # Hanami::Action::CSRFProtection, without reimplementing either side:
    #
    # - Inertia's HTTP client automatically reads an XSRF-TOKEN cookie and
    #   echoes it back as an X-XSRF-TOKEN header on every request.
    # - Hanami::Action::CSRFProtection stores its challenge token in the
    #   session and only checks for it via the `_csrf_token` param or an
    #   X-CSRF-Token header — it never exposes the token as a cookie.
    #
    # This middleware translates between the two: an incoming X-XSRF-TOKEN
    # header is copied into X-CSRF-Token before the request reaches the
    # action, and once the action has minted/reused the session's CSRF
    # token, it's mirrored into a readable XSRF-TOKEN cookie on the way out.
    class Csrf
      COOKIE_NAME = "XSRF-TOKEN"
      # Hanami::Action::Request::Session#[]= always stringifies keys before
      # writing to the underlying rack.session store, regardless of the
      # symbol Hanami::Action::CSRFProtection itself indexes with - so the
      # token lands under this string key, not :_csrf_token.
      SESSION_KEY = "_csrf_token"

      def initialize(app)
        @app = app
      end

      def call(env)
        bridge_incoming_token(env)

        status, headers, body = @app.call(env)

        expose_outgoing_token(env, headers)

        [status, headers, body]
      end

      private

      def bridge_incoming_token(env)
        token = env["HTTP_X_XSRF_TOKEN"]
        env["HTTP_X_CSRF_TOKEN"] ||= token if token
      end

      def expose_outgoing_token(env, headers)
        session = env["rack.session"]
        token = session && session[SESSION_KEY]
        return unless token

        request = Rack::Request.new(env)
        Rack::Utils.set_cookie_header!(
          headers, COOKIE_NAME,
          { value: token, path: "/", secure: request.ssl?, same_site: :lax }
        )
      end
    end
  end
end
