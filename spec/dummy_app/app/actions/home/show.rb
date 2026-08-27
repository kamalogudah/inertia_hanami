# frozen_string_literal: true

module DummyApp
  module Actions
    module Home
      class Show < DummyApp::Action
        include InertiaHanami::Action
        def handle(_request, _response)
          props = {
            greeting: "Hello from DummyApp",
            extra: "Extra prop",
            bio: InertiaHanami::Props::Optional.new(block: -> { "Optional bio" }),
            stats: InertiaHanami::Props::Defer.new(group: "content", block: -> { "Deferred stats" }),
            activity: InertiaHanami::Props::Defer.new(group: "content", block: -> { "Deferred activity" })
          }
          inertia_render("Home/Show", props: props)
        end
      end
    end
  end
end
