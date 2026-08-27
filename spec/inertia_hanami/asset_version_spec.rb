# frozen_string_literal: true

require "tmpdir"
require "digest"

RSpec.describe InertiaHanami::AssetVersion do
  describe ".digest" do
    it "returns a SHA256 hex digest of the assets.json manifest" do
      Dir.mktmpdir do |dir|
        manifest_path = File.join(dir, "assets.json")
        File.write(manifest_path, '{"app.js":{"url":"/assets/app-abc123.js"}}')

        expect(described_class.digest(dir)).to eq(Digest::SHA256.file(manifest_path).hexdigest)
      end
    end

    it "changes when the manifest content changes" do
      Dir.mktmpdir do |dir|
        manifest_path = File.join(dir, "assets.json")

        File.write(manifest_path, '{"app.js":{"url":"/assets/app-abc123.js"}}')
        first_digest = described_class.digest(dir)

        File.write(manifest_path, '{"app.js":{"url":"/assets/app-def456.js"}}')
        second_digest = described_class.digest(dir)

        expect(first_digest).not_to eq(second_digest)
      end
    end

    it "returns nil when the manifest file does not exist" do
      Dir.mktmpdir do |dir|
        expect(described_class.digest(dir)).to be_nil
      end
    end

    it "returns nil when assets_root is nil" do
      expect(described_class.digest(nil)).to be_nil
    end
  end
end
