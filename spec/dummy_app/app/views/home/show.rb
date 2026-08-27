# frozen_string_literal: true

module DummyApp
  module Views
    module Home
      class Show < DummyApp::View
        expose :page, layout: true
        expose :ssr_head, layout: true
        expose :ssr_body, layout: true
      end
    end
  end
end
