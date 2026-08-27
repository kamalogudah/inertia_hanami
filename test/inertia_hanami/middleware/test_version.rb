# frozen_string_literal: true

require "test_helper"
require "rack/mock"

class TestMiddlewareVersion < Minitest::Test
  def setup
    config_class = Struct.new(:version)
    @config = config_class.new("abc123")

    downstream = ->(_env) { [200, {}, ["ok"]] }
    @app = InertiaHanami::Middleware::Version.new(downstream)
  end

  def call(method:, headers: {})
    with_stubbed_config do
      env = Rack::MockRequest.env_for("/", method: method, "HTTP_X_INERTIA" => "true")
      headers.each { |k, v| env[k] = v }
      @app.call(env)
    end
  end

  def test_passes_through_when_version_matches
    status, = call(method: "GET", headers: { "HTTP_X_INERTIA_VERSION" => "abc123" })
    assert_equal 200, status
  end

  def test_409_on_version_mismatch_for_get
    status, headers, body = call(method: "GET", headers: { "HTTP_X_INERTIA_VERSION" => "old" })
    assert_equal 409, status
    assert headers["X-Inertia-Location"]
    assert_equal [""], body
  end

  def test_passes_through_for_non_get_even_on_mismatch
    status, = call(method: "POST", headers: { "HTTP_X_INERTIA_VERSION" => "old" })
    assert_equal 200, status
  end

  def test_passes_through_for_non_inertia_requests
    env = Rack::MockRequest.env_for("/", method: "GET")
    env["HTTP_X_INERTIA_VERSION"] = "old"
    status, = with_stubbed_config { @app.call(env) }
    assert_equal 200, status
  end

  private

  def with_stubbed_config
    config = @config
    container = Object.new
    container.define_singleton_method(:[]) { |_key| config }

    Hanami.define_singleton_method(:app) { container }
    yield
  ensure
    Hanami.singleton_class.send(:remove_method, :app)
  end
end
