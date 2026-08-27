# frozen_string_literal: true

RSpec.describe InertiaHanami::Configuration do
  subject(:configuration) { described_class.new.config }

  it "defaults version to nil" do
    expect(configuration.version).to be_nil
  end

  it "defaults root_view to app" do
    expect(configuration.root_view).to eq("app")
  end

  it "defaults root_dom_id to app" do
    expect(configuration.root_dom_id).to eq("app")
  end

  it "defaults component_path_resolver to the identity lambda" do
    expect(configuration.component_path_resolver.call("Pages/Home")).to eq("Pages/Home")
  end

  it "defaults ssr to disabled with a local url" do
    expect(configuration.ssr.enabled).to be(false)
    expect(configuration.ssr.url).to eq("http://localhost:13714")
  end

  it "defaults always_include_errors_hash to false" do
    expect(configuration.always_include_errors_hash).to be(false)
  end

  it "defaults encrypt_history to false" do
    expect(configuration.encrypt_history).to be(false)
  end

  it "allows settings to be overridden per instance" do
    configuration.root_dom_id = "custom"

    expect(configuration.root_dom_id).to eq("custom")
    expect(described_class.new.config.root_dom_id).to eq("app")
  end
end
