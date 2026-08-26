# frozen_string_literal: true

require "hanami"

module DummyApp
  class App < Hanami::App
    config.root = File.expand_path("..", __dir__)
  end
end
