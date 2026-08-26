# frozen_string_literal: true

module DummyApp
  class Routes < Hanami::Routes
    root to: "home.show"
  end
end
