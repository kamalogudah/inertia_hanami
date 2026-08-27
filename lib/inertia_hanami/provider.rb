# frozen_string_literal: true

require "hanami"
require "dry/system"
require "hanami/provider/source"

module InertiaHanami
  class Provider < Hanami::Provider::Source
    def prepare
      require "inertia_hanami/configuration"
      require "inertia_hanami/asset_version"
    end

    def start
      configuration = InertiaHanami::Configuration.new

      if configuration.config.version.nil?
        configuration.config.version = InertiaHanami::AssetVersion.digest(assets_root)
      end

      register("config", configuration.config)
    end

    private

    def assets_root
      return nil unless target.container.providers.key?(:assets)

      target.start(:assets)
      target[:assets].root
    end
  end
end
