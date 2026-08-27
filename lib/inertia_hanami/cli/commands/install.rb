# frozen_string_literal: true

require "generators/inertia_hanami/install_generator"

module InertiaHanami
  module CLI
    module Commands
      # `hanami generate inertia:install` - scaffolds the provider, middleware
      # wiring, layout, view helper, and a sample page for inertia_hanami.
      class Install < Hanami::CLI::Commands::App::Command
        option :force, type: :flag, default: false, desc: "Overwrite existing files during generation"
        option :framework, default: "react", values: InertiaHanami::Generators::InstallGenerator::FRAMEWORK_PACKAGES.keys,
                           desc: "Frontend framework for @inertiajs/* package.json guidance"

        example [
          %(               (scaffolds provider, layout, helper, sample page, react npm guidance)),
          %(--framework=vue (npm guidance targets @inertiajs/vue3 instead)),
          %(--force         (overwrite files this command previously generated))
        ]

        def call(force:, framework:, **)
          InertiaHanami::Generators::InstallGenerator.new(
            fs: fs, inflector: inflector, out: out
          ).call(base_path: app.root, namespace: app.namespace, framework: framework, force: force)
        end
      end
    end
  end
end
