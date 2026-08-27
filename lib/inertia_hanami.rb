# frozen_string_literal: true

require_relative "inertia_hanami/version"
require_relative "inertia_hanami/configuration"
require_relative "inertia_hanami/provider"
require_relative "inertia_hanami/props"
require_relative "inertia_hanami/prop_evaluator"
require_relative "inertia_hanami/protocol_builder"
require_relative "inertia_hanami/request_context"
require_relative "inertia_hanami/ssr_renderer"
require_relative "inertia_hanami/renderer"
require_relative "inertia_hanami/action"
require_relative "inertia_hanami/helper"
require_relative "inertia_hanami/middleware/version"
require_relative "inertia_hanami/middleware/redirects"

module InertiaHanami
  class Error < StandardError; end
end

# Only loaded when the `hanami` executable has already required hanami-cli
# (e.g. this gem is placed in Bundler's `:cli` group) - adds zero runtime
# dependency on hanami-cli for normal app boot.
require "inertia_hanami/cli" if defined?(Hanami::CLI)
