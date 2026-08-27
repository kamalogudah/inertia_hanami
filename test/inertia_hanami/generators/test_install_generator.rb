# frozen_string_literal: true

require "test_helper"
require "json"
require "stringio"
require "dry/files"
require "dry/inflector"
require "generators/inertia_hanami/install_generator"

class TestInstallGenerator < Minitest::Test
  ROOT = "/app"

  def setup
    @fs = Dry::Files.new(memory: true)
    @out = StringIO.new
    @generator = InertiaHanami::Generators::InstallGenerator.new(fs: @fs, inflector: Dry::Inflector.new, out: @out)
    @fs.write("#{ROOT}/config/app.rb", <<~RUBY)
      # frozen_string_literal: true

      require "hanami"

      module DummyApp
        class App < Hanami::App
          config.root = File.expand_path("..", __dir__)
        end
      end
    RUBY
    @fs.write("#{ROOT}/config/routes.rb", <<~RUBY)
      # frozen_string_literal: true

      module DummyApp
        class Routes < Hanami::Routes
          root to: "home.show"
        end
      end
    RUBY
  end

  def install(**opts)
    @generator.call(base_path: ROOT, namespace: "DummyApp", **opts)
  end

  def file(*parts)
    @fs.join(ROOT, *parts)
  end

  def test_fresh_install_creates_all_files
    install

    assert @fs.exist?(file("config/providers/inertia.rb"))
    assert_includes @fs.read(file("config/providers/inertia.rb")), "register_provider(:inertia"

    assert @fs.exist?(file("app/templates/layouts/app.html.erb"))
    assert_includes @fs.read(file("app/templates/layouts/app.html.erb")), "<%= inertia_root(page: page) %>"

    assert @fs.exist?(file("app/views/helpers.rb"))
    assert_includes @fs.read(file("app/views/helpers.rb")), "include InertiaHanami::Helper"

    assert @fs.exist?(file("app/actions/inertia_example/show.rb"))
    assert @fs.exist?(file("app/views/inertia_example/show.rb"))
    assert @fs.exist?(file("app/templates/inertia_example/show.html.erb"))

    assert_includes @fs.read(file("config/app.rb")), "config.middleware.use InertiaHanami::Middleware::Version"
    assert_includes @fs.read(file("config/app.rb")), "config.middleware.use InertiaHanami::Middleware::Redirects"

    assert_includes @fs.read(file("config/routes.rb")), %(get "/inertia-example", to: "inertia_example.show")
  end

  def test_rerun_without_force_skips_existing_files_and_does_not_duplicate_injections
    install
    install

    app_rb = @fs.read(file("config/app.rb"))
    assert_equal 1, app_rb.scan("config.middleware.use InertiaHanami::Middleware::Version").size

    routes_rb = @fs.read(file("config/routes.rb"))
    assert_equal 1, routes_rb.scan('to: "inertia_example.show"').size

    helpers_rb = @fs.read(file("app/views/helpers.rb"))
    assert_equal 1, helpers_rb.scan("include InertiaHanami::Helper").size
  end

  def test_force_overwrites_existing_files
    @fs.write(file("config/providers/inertia.rb"), "# stale")
    install(force: true)

    refute_includes @fs.read(file("config/providers/inertia.rb")), "stale"
  end

  def test_helpers_injection_into_existing_file
    @fs.write(file("app/views/helpers.rb"), <<~RUBY)
      # frozen_string_literal: true

      module DummyApp
        module Views
          module Helpers
          end
        end
      end
    RUBY

    install

    helpers_rb = @fs.read(file("app/views/helpers.rb"))
    assert_includes helpers_rb, 'require "inertia_hanami/helper"'
    assert_includes helpers_rb, "include InertiaHanami::Helper"
  end

  def test_package_json_merges_framework_dependencies
    @fs.write(file("package.json"), JSON.generate({ "name" => "dummy_app", "dependencies" => { "vite" => "^5.0.0" } }))

    install(framework: "vue")

    data = JSON.parse(@fs.read(file("package.json")))
    assert_equal "^5.0.0", data["dependencies"]["vite"]
    assert data["dependencies"].key?("@inertiajs/vue3")
    assert data["dependencies"].key?("vue")
  end

  def test_no_package_json_prints_npm_guidance
    install(framework: "svelte")

    refute @fs.exist?(file("package.json"))
    assert_includes @out.string, "npm install @inertiajs/svelte svelte"
  end

  def test_unknown_framework_raises
    assert_raises(ArgumentError) { install(framework: "angular") }
  end
end
