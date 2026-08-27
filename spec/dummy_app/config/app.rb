# frozen_string_literal: true

require "hanami"
require "inertia_hanami/middleware/version"
require "inertia_hanami/middleware/redirects"

module DummyApp
  class App < Hanami::App
    config.root = File.expand_path("..", __dir__)

    config.middleware.use InertiaHanami::Middleware::Version
    config.middleware.use InertiaHanami::Middleware::Redirects
  end
end
