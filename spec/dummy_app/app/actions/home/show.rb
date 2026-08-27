# frozen_string_literal: true

module DummyApp
  module Actions
    module Home
      class Show < DummyApp::Action
        include InertiaHanami::Action

        def handle(_request, _response)
          inertia_render("Home/Show", props: { greeting: "Hello from DummyApp" })
        end
      end
    end
  end
end
