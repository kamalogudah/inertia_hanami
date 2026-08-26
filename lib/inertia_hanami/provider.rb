# frozen_string_literal: true

require "hanami"
require "dry/system"
require "hanami/provider/source"

module InertiaHanami
  class Provider < Hanami::Provider::Source
    def prepare
      require "inertia_hanami/configuration"
    end

    def start
      register("config", InertiaHanami::Configuration.new.config)
    end
  end
end
