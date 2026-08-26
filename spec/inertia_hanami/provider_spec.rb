# frozen_string_literal: true

RSpec.describe "inertia.config provider" do
  it "registers InertiaHanami::Configuration's settings under the inertia.config key" do
    expect(Hanami.app["inertia.config"]).to respond_to(:version, :root_view, :root_dom_id, :ssr)
  end

  it "exposes the default configuration values" do
    config = Hanami.app["inertia.config"]

    expect(config.root_view).to eq("app")
    expect(config.root_dom_id).to eq("app")
  end
end
