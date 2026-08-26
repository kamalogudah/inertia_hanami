# frozen_string_literal: true

require "dry/configurable"

module InertiaHanami
  class Configuration
    include Dry::Configurable

    setting :version, default: nil
    setting :root_view, default: "app"
    setting :root_dom_id, default: "app"
    setting :component_path_resolver, default: ->(component) { component }

    setting :ssr do
      setting :enabled, default: false
      setting :url, default: "http://localhost:13714"
    end
  end
end
