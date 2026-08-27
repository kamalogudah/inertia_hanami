# frozen_string_literal: true

module DummyApp
  module Actions
    module Session
      class SetFlashAndErrors < DummyApp::Action
        include InertiaHanami::Action

        def handle(_request, response)
          share_inertia_errors(name: ["is required"])
          response.flash[:notice] = "Saved!"
          response.redirect_to("/")
        end
      end
    end
  end
end
