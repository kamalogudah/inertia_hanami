# frozen_string_literal: true

module DummyApp
  module Views
    module Home
      class Show < DummyApp::View
        expose :greeting do
          "Hello from DummyApp"
        end
      end
    end
  end
end
