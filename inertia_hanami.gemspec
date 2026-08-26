# frozen_string_literal: true

require_relative "lib/inertia_hanami/version"

Gem::Specification.new do |spec|
  spec.name = "inertia_hanami"
  spec.version = InertiaHanami::VERSION
  spec.authors = ["Paul Oguda"]
  spec.email = ["mcpaul2058@gmail.com"]

  spec.summary = "Inertia.js protocol adapter for Hanami"
  spec.description = "Server-side adapter implementing the Inertia.js protocol for the Hanami web framework."
  spec.homepage = "https://github.com/kamalogudah/inertia_hanami"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 3.2.0"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = "#{spec.homepage}/tree/main"
  spec.metadata["changelog_uri"] = "#{spec.homepage}/blob/main/CHANGELOG.md"

  # Specify which files should be added to the gem when it is released.
  # The `git ls-files -z` loads the files in the RubyGem that have been added into git.
  gemspec = File.basename(__FILE__)
  spec.files = IO.popen(%w[git ls-files -z], chdir: __dir__, err: IO::NULL) do |ls|
    ls.readlines("\x0", chomp: true).reject do |f|
      (f == gemspec) ||
        f.start_with?(*%w[bin/ Gemfile .gitignore test/ spec/ .github/ .rubocop.yml])
    end
  end
  spec.bindir = "exe"
  spec.executables = spec.files.grep(%r{\Aexe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.add_dependency "dry-configurable", "~> 1.0"

  spec.add_development_dependency "hanami"
  spec.add_development_dependency "hanami-action"
  spec.add_development_dependency "hanami-router"
  spec.add_development_dependency "hanami-view"
  spec.add_development_dependency "rack-test"
  spec.add_development_dependency "rspec"
end
