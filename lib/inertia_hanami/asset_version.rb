# frozen_string_literal: true

require "digest"
require "pathname"

module InertiaHanami
  # Derives an Inertia asset version string from hanami-assets' assets.json
  # manifest, mirroring the role ViteRuby.digest plays for inertia-rails.
  module AssetVersion
    MANIFEST_FILENAME = "assets.json"

    # Returns a SHA256 hex digest of the assets.json manifest under `assets_root`,
    # or nil if no manifest is present (e.g. assets not yet compiled).
    def self.digest(assets_root)
      return nil if assets_root.nil?

      manifest_path = Pathname(assets_root).join(MANIFEST_FILENAME)
      return nil unless manifest_path.file?

      Digest::SHA256.file(manifest_path).hexdigest
    end
  end
end
