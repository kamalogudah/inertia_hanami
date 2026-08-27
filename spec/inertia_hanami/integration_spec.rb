# frozen_string_literal: true

require "rack/test"

RSpec.describe "full-stack request through the dummy app" do
  include Rack::Test::Methods

  def app
    Hanami.app
  end

  context "on an initial full-page load (no X-Inertia header)" do
    it "renders the layout with the Inertia root div and the page envelope JSON-encoded" do
      get "/"

      expect(last_response.status).to eq(200)
      expect(last_response.body).to match(%r{<div id="app" data-page="([^"]*)"></div>})

      encoded = last_response.body.match(/data-page="([^"]*)"/)[1]
      page = JSON.parse(CGI.unescapeHTML(encoded))

      expect(page).to include(
        "component" => "Home/Show",
        "props" => { "greeting" => "Hello from DummyApp" }
      )
    end
  end

  context "on an Inertia XHR request (X-Inertia: true)" do
    it "responds with the JSON page envelope instead of HTML" do
      get "/", {}, { "HTTP_X_INERTIA" => "true" }

      expect(last_response.headers["X-Inertia"]).to eq("true")
      page = JSON.parse(last_response.body)
      expect(page).to include("component" => "Home/Show")
    end
  end
end
