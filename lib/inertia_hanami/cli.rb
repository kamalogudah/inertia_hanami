# frozen_string_literal: true

# Registers `hanami generate inertia:install` with the Hanami CLI.
#
# Only loaded when `Hanami::CLI` is already defined (see
# `inertia_hanami.rb`) - i.e. when this gem is required from Bundler's
# `:cli` group, the same convention `hanami-reloader` and `hanami-rspec`
# use to hook into `hanami generate`/`hanami server` without hanami-cli
# needing to know about third-party gems in advance.

require "hanami/cli"
require "inertia_hanami/cli/commands/install"

if Hanami::CLI.within_hanami_app?
  Hanami::CLI.register("generate inertia:install", InertiaHanami::CLI::Commands::Install)
end
