# frozen_string_literal: true

require "inertia_hanami/testing/rspec"
require "rack/test"

RSpec.describe "InertiaHanami RSpec testing helpers" do
  include Rack::Test::Methods

  def app
    Hanami.app
  end

  def current_version
    Hanami.app["inertia.config"].version
  end

  def get_inertia(path = "/")
    get path, {}, { "HTTP_X_INERTIA" => "true", "HTTP_X_INERTIA_VERSION" => current_version }
  end

  context "against an XHR Inertia request" do
    before { get_inertia }

    it { expect(inertia).to be_inertia_response }
    it { expect(inertia).to render_component("Home/Show") }
    it { expect(inertia).to have_props(greeting: "Hello from DummyApp") }
    it { expect(inertia).to(have_props { |props| props[:greeting].start_with?("Hello") }) }
    it { expect(inertia).to have_exact_props(greeting: "Hello from DummyApp", extra: "Extra prop") }
    it { expect(inertia).to have_no_prop(:bio) }
    it { expect(inertia).to have_no_prop(:stats) }
    it { expect(inertia).not_to have_no_prop(:greeting) }
    it { expect(inertia).not_to render_component("Other/Component") }
  end

  context "against a non-Inertia response" do
    before { get "/this-route-does-not-exist" }

    it { expect(inertia).not_to be_inertia_response }
  end

  context "#inertia_reload_only" do
    before do
      get_inertia
      inertia_reload_only("greeting")
    end

    it { expect(inertia).to have_exact_props(greeting: "Hello from DummyApp") }
  end

  context "#inertia_reload_except" do
    before do
      get_inertia
      inertia_reload_except("extra")
    end

    it { expect(inertia).to have_no_prop(:extra) }
    it { expect(inertia).to have_props(greeting: "Hello from DummyApp") }
  end

  context "#inertia_load_deferred_props" do
    before { get_inertia }

    it "loads a named group" do
      inertia_load_deferred_props(:content)
      expect(inertia).to have_props(stats: "Deferred stats", activity: "Deferred activity")
    end

    it "loads all deferred groups when no group is given" do
      inertia_load_deferred_props
      expect(inertia).to have_props(stats: "Deferred stats")
    end
  end

  context "against an initial (non-XHR) load" do
    before { get "/" }

    it { expect(inertia).to be_inertia_response }
    it { expect(inertia).to render_component("Home/Show") }
    it { expect(inertia).to have_props(greeting: "Hello from DummyApp") }
  end
end
