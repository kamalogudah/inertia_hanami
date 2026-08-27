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

  it "derives version from the hanami-assets manifest digest" do
    manifest_path = Hanami.app.root.join("public", "assets", "assets.json")
    expected_version = Digest::SHA256.file(manifest_path).hexdigest

    expect(Hanami.app["inertia.config"].version).to eq(expected_version)
  end
end
