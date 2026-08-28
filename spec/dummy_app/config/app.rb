# frozen_string_literal: true

require "hanami"
require "securerandom"
require "inertia_hanami/middleware/version"
require "inertia_hanami/middleware/redirects"
require "inertia_hanami/middleware/csrf"

module DummyApp
  class App < Hanami::App
    config.root = File.expand_path("..", __dir__)

    config.middleware.use InertiaHanami::Middleware::Version
    config.middleware.use InertiaHanami::Middleware::Redirects
    config.middleware.use InertiaHanami::Middleware::Csrf

    config.actions.sessions = :cookie, { secret: SecureRandom.hex(32) }
  end
end
