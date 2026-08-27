# frozen_string_literal: true

require "erb"
require "json"
require "dry/files"

module InertiaHanami
  module Generators
    # Scaffolds everything a Hanami app needs to start using inertia_hanami:
    # the provider, middleware wiring, layout, view helper, a sample page,
    # and @inertiajs/* package.json guidance.
    #
    # Mirrors the shape of hanami-cli's own generators (`fs:`, `inflector:`,
    # `out:` injected, `#call` performs the work), so it composes naturally
    # with `Hanami::CLI::Commands::App::Command` subclasses.
    class InstallGenerator
      TEMPLATES_DIR = File.expand_path("templates", __dir__)

      FRAMEWORK_PACKAGES = {
        "react" => %w[@inertiajs/react react react-dom],
        "vue" => %w[@inertiajs/vue3 vue],
        "svelte" => %w[@inertiajs/svelte svelte]
      }.freeze

      def initialize(fs:, inflector:, out:)
        @fs = fs
        @inflector = inflector
        @out = out
      end

      def call(base_path:, namespace:, framework: "react", force: false)
        unless FRAMEWORK_PACKAGES.key?(framework.to_s)
          raise ArgumentError, "unknown framework #{framework.inspect}, expected one of #{FRAMEWORK_PACKAGES.keys}"
        end

        @base_path = base_path.to_s
        @namespace = namespace.to_s
        @framework = framework.to_s
        @force = force

        generate_provider
        generate_middleware
        generate_layout
        generate_helpers
        generate_sample_page
        generate_package_json_guidance

        out.puts
        out.puts "Next steps:"
        out.puts "  - Run `npm install` (or yarn/pnpm) to install the @inertiajs/* packages."
        out.puts "  - Wire up your JS entrypoint (Vite/hanami-assets config) - inertia_hanami " \
                 "does not manage frontend bundling."
      end

      private

      attr_reader :fs, :inflector, :out, :base_path, :namespace, :framework, :force

      def path(*parts)
        fs.join(base_path, *parts)
      end

      def render(template)
        erb_binding = binding
        erb_binding.local_variable_set(:namespace, @namespace)
        ERB.new(File.read(File.join(TEMPLATES_DIR, template)), trim_mode: "-").result(erb_binding)
      end

      def create(relative_path, content, force: self.force)
        full_path = path(relative_path)

        if fs.exist?(full_path) && !force
          out.puts "      skip  #{relative_path} (already exists)"
          return false
        end

        fs.write(full_path, content)
        out.puts "    create  #{relative_path}"
        true
      end

      def generate_provider
        create("config/providers/inertia.rb", render("provider.rb.erb"))
      end

      def generate_middleware
        app_file = path("config/app.rb")

        unless fs.exist?(app_file)
          out.puts "      skip  config/app.rb (not found - register the middleware manually)"
          return
        end

        content = fs.read(app_file)

        if content.include?("InertiaHanami::Middleware::Version") &&
           content.include?("InertiaHanami::Middleware::Redirects")
          out.puts "      skip  config/app.rb (middleware already registered)"
          return
        end

        unless content.include?('require "inertia_hanami/middleware/version"')
          fs.inject_line_before(app_file, /^module /, 'require "inertia_hanami/middleware/version"')
        end
        unless content.include?('require "inertia_hanami/middleware/redirects"')
          fs.inject_line_before(app_file, /^module /, 'require "inertia_hanami/middleware/redirects"')
        end

        fs.inject_line_at_class_bottom(
          app_file, /class .* < Hanami::App/,
          ["config.middleware.use InertiaHanami::Middleware::Version",
           "config.middleware.use InertiaHanami::Middleware::Redirects"]
        )
        out.puts "    update  config/app.rb"
      rescue Dry::Files::MissingTargetError
        out.puts "      skip  config/app.rb (unrecognized format - add the middleware manually: " \
                 "config.middleware.use InertiaHanami::Middleware::Version / ::Redirects)"
      end

      def generate_layout
        create("app/templates/layouts/app.html.erb", render("layout.html.erb.erb"))
      end

      def generate_helpers
        helpers_file = path("app/views/helpers.rb")

        unless fs.exist?(helpers_file)
          create("app/views/helpers.rb", render("helpers.rb.erb"))
          return
        end

        content = fs.read(helpers_file)

        if content.include?("InertiaHanami::Helper")
          out.puts "      skip  app/views/helpers.rb (already includes InertiaHanami::Helper)"
          return
        end

        unless content.include?('require "inertia_hanami/helper"')
          fs.inject_line_before(helpers_file, /^module /, 'require "inertia_hanami/helper"')
        end
        fs.inject_line_at_class_bottom(helpers_file, /module Helpers/, "include InertiaHanami::Helper")
        out.puts "    update  app/views/helpers.rb"
      rescue Dry::Files::MissingTargetError
        out.puts "      skip  app/views/helpers.rb (unrecognized format - add " \
                 "`include InertiaHanami::Helper` to it manually)"
      end

      def generate_sample_page
        create("app/actions/inertia_example/show.rb", render("sample_action.rb.erb"))
        create("app/views/inertia_example/show.rb", render("sample_view.rb.erb"))
        create("app/templates/inertia_example/show.html.erb", render("sample_template.html.erb.erb"))

        routes_file = path("config/routes.rb")
        unless fs.exist?(routes_file)
          out.puts "      skip  config/routes.rb (not found - add the route manually)"
          return
        end

        content = fs.read(routes_file)
        if content.include?('"inertia_example.show"')
          out.puts "      skip  config/routes.rb (route already present)"
          return
        end

        fs.inject_line_at_class_bottom(
          routes_file, /class .* < Hanami::Routes/,
          %(get "/inertia-example", to: "inertia_example.show")
        )
        out.puts "    update  config/routes.rb"
      rescue Dry::Files::MissingTargetError
        out.puts "      skip  config/routes.rb (unrecognized format - add the route manually: " \
                 'get "/inertia-example", to: "inertia_example.show")'
      end

      def generate_package_json_guidance
        packages = FRAMEWORK_PACKAGES.fetch(framework)
        package_json_file = path("package.json")

        unless fs.exist?(package_json_file)
          out.puts
          out.puts "No package.json found - install the frontend packages yourself:"
          out.puts "  npm install #{packages.join(" ")}"
          return
        end

        data = JSON.parse(fs.read(package_json_file))
        dependencies = (data["dependencies"] ||= {})
        added = packages.reject { |pkg| dependencies.key?(pkg) }

        if added.empty?
          out.puts "      skip  package.json (@inertiajs/* dependencies already present)"
          return
        end

        added.each { |pkg| dependencies[pkg] = "latest" }
        fs.write(package_json_file, "#{JSON.pretty_generate(data)}\n")
        out.puts "    update  package.json (added #{added.join(", ")})"
      end
    end
  end
end
