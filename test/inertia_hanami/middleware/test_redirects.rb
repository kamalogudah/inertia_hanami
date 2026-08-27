# frozen_string_literal: true

require "test_helper"
require "rack/mock"

class TestMiddlewareRedirects < Minitest::Test
  def setup
    @downstream_status = 302
    @downstream_headers = { "Location" => "/somewhere" }

    downstream = ->(_env) { [@downstream_status, @downstream_headers, ["ok"]] }
    @app = InertiaHanami::Middleware::Redirects.new(downstream)
  end

  def call(method:, inertia: true)
    headers = inertia ? { "HTTP_X_INERTIA" => "true" } : {}
    env = Rack::MockRequest.env_for("/", method: method)
    headers.each { |k, v| env[k] = v }
    @app.call(env)
  end

  def test_rewrites_302_to_303_for_put_on_inertia_request
    status, = call(method: "PUT")
    assert_equal 303, status
  end

  def test_rewrites_301_to_303_for_delete_on_inertia_request
    @downstream_status = 301
    status, = call(method: "DELETE")
    assert_equal 303, status
  end

  def test_rewrites_302_to_303_for_patch_on_inertia_request
    status, = call(method: "PATCH")
    assert_equal 303, status
  end

  def test_does_not_rewrite_for_get
    status, = call(method: "GET")
    assert_equal 302, status
  end

  def test_does_not_rewrite_for_non_inertia_request
    status, = call(method: "PUT", inertia: false)
    assert_equal 302, status
  end

  def test_leaves_non_redirect_responses_untouched
    @downstream_status = 200
    @downstream_headers = {}
    status, = call(method: "PUT")
    assert_equal 200, status
  end

  def test_external_redirect_becomes_409_with_x_inertia_location
    @downstream_headers = { "Location" => "https://evil.example.com/phishing" }
    status, headers, body = call(method: "GET")

    assert_equal 409, status
    assert_equal "https://evil.example.com/phishing", headers["X-Inertia-Location"]
    assert_nil headers["Location"]
    assert_equal [""], body
  end

  def test_same_origin_redirect_is_not_treated_as_external
    @downstream_headers = { "Location" => "http://example.org/somewhere" }
    status, headers, = call(method: "GET")

    assert_equal 302, status
    assert_equal "http://example.org/somewhere", headers["Location"]
  end

  def test_external_redirect_check_ignored_for_non_inertia_request
    @downstream_headers = { "Location" => "https://evil.example.com/phishing" }
    status, = call(method: "GET", inertia: false)

    assert_equal 302, status
  end
end
