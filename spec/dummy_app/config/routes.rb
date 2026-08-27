# frozen_string_literal: true

module DummyApp
  class Routes < Hanami::Routes
    root to: "home.show"
    get "/set-flash-and-errors", to: "session.set_flash_and_errors"
  end
end
