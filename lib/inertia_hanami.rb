# frozen_string_literal: true

require_relative "inertia_hanami/version"
require_relative "inertia_hanami/configuration"
require_relative "inertia_hanami/provider"
require_relative "inertia_hanami/props"
require_relative "inertia_hanami/prop_evaluator"
require_relative "inertia_hanami/protocol_builder"

module InertiaHanami
  class Error < StandardError; end
end
