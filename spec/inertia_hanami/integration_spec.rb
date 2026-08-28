# frozen_string_literal: true

require "rack/test"

RSpec.describe "full-stack request through the dummy app" do
  include Rack::Test::Methods

  def app
    Hanami.app
  end

  def current_version
    Hanami.app["inertia.config"].version
  end

  context "on an initial full-page load (no X-Inertia header)" do
    it "renders the layout with the Inertia script tag, root div, and the page envelope JSON-encoded" do
      get "/"

      expect(last_response.status).to eq(200)
      expect(last_response.body).to match(%r{<script data-page="app" type="application/json">([^<]*)</script>})
      expect(last_response.body).to include(%(<div id="app"></div>))

      encoded = last_response.body.match(%r{<script data-page="app" type="application/json">([^<]*)</script>})[1]
      page = JSON.parse(CGI.unescapeHTML(encoded))

      expect(page).to include(
        "component" => "Home/Show",
        "props" => { "greeting" => "Hello from DummyApp", "extra" => "Extra prop" }
      )
    end
  end

  context "on an Inertia XHR request (X-Inertia: true)" do
    it "responds with the JSON page envelope instead of HTML" do
      get "/", {}, { "HTTP_X_INERTIA" => "true", "HTTP_X_INERTIA_VERSION" => current_version }

      expect(last_response.headers["X-Inertia"]).to eq("true")
      page = JSON.parse(last_response.body)
      expect(page).to include(
        "component" => "Home/Show",
        "props" => { "greeting" => "Hello from DummyApp", "extra" => "Extra prop" }
      )
    end
  end

  context "on a partial reload (X-Inertia-Partial-Data)" do
    it "returns only the requested props, filtering out the rest" do
      get "/", {}, {
        "HTTP_X_INERTIA" => "true",
        "HTTP_X_INERTIA_VERSION" => current_version,
        "HTTP_X_INERTIA_PARTIAL_COMPONENT" => "Home/Show",
        "HTTP_X_INERTIA_PARTIAL_DATA" => "greeting"
      }

      page = JSON.parse(last_response.body)
      expect(page["props"]).to eq("greeting" => "Hello from DummyApp")
    end
  end

  context "on a version mismatch (X-Inertia-Version doesn't match the server's)" do
    it "responds with 409 + X-Inertia-Location instead of calling the action" do
      get "/", {}, {
        "HTTP_X_INERTIA" => "true",
        "HTTP_X_INERTIA_VERSION" => "stale-version"
      }

      expect(last_response.status).to eq(409)
      expect(last_response.headers["X-Inertia-Location"]).to end_with("/")
      expect(last_response.body).to eq("")
    end
  end
end
