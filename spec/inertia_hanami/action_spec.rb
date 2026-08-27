# frozen_string_literal: true

require "hanami/action"
require "rack/mock"

ActionSpecFakeView = Struct.new(:output) do
  def call(**) = output
end

RSpec.describe InertiaHanami::Action do
  def call_action(klass, headers: {}, view: nil)
    env = Rack::MockRequest.env_for("/users/1", headers)
    action = klass.new(view: view)
    response = action.call(env)
    body = +""
    response.each { |part| body << part }
    [response.status, response.headers, body]
  end

  let(:action_class) do
    Class.new(Hanami::Action) do
      include InertiaHanami::Action
    end
  end

  describe "#auto_render?" do
    it "returns false for an Inertia XHR request, bypassing the view" do
      klass = Class.new(action_class) do
        def handle(*); end
      end

      _status, _headers, body = call_action(klass, headers: { "HTTP_X_INERTIA" => "true" },
                                                   view: ActionSpecFakeView.new("<html></html>"))

      expect(body).not_to eq("<html></html>")
    end

    it "falls back to normal auto-rendering for a non-Inertia request" do
      klass = Class.new(action_class) do
        def handle(*); end
      end

      _status, _headers, body = call_action(klass, view: ActionSpecFakeView.new("<html></html>"))

      expect(body).to eq("<html></html>")
    end
  end

  describe "#inertia_render" do
    it "merges class-level and instance-level shared props (shallow) under explicit props" do
      action_class.inertia_share(site_name: "Acme")
      action_class.inertia_share { { locale: "en" } }

      klass = Class.new(action_class) do
        def handle(_request, _response)
          inertia_share(user: "Ada")
          inertia_share { { locale: "fr" } }
          inertia_render("Users/Show", props: { name: "Grace" })
        end
      end

      _status, _headers, body = call_action(klass, headers: { "HTTP_X_INERTIA" => "true" })
      page = JSON.parse(body)

      expect(page["props"]).to eq(
        "site_name" => "Acme",
        "locale" => "fr",
        "user" => "Ada",
        "name" => "Grace"
      )
    end

    it "forwards component/url/version/history flags to the Renderer" do
      klass = Class.new(action_class) do
        def handle(_request, _response)
          inertia_render("Users/Show", props: {}, url: "/custom", version: "v1",
                                       encrypt_history: true, clear_history: true)
        end
      end

      _status, _headers, body = call_action(klass, headers: { "HTTP_X_INERTIA" => "true" })
      page = JSON.parse(body)

      expect(page).to include(
        "component" => "Users/Show",
        "url" => "/custom",
        "version" => "v1",
        "encryptHistory" => true,
        "clearHistory" => true
      )
    end

    it "defaults version from the inertia config when not given explicitly" do
      klass = Class.new(action_class) do
        def handle(_request, _response)
          inertia_render("Users/Show", props: {})
        end
      end

      _status, _headers, body = call_action(klass, headers: { "HTTP_X_INERTIA" => "true" })
      page = JSON.parse(body)

      expect(page["version"]).to eq(Hanami.app["inertia.config"].version)
    end
  end

  describe "#inertia_location" do
    it "sets a 409 + X-Inertia-Location header for an Inertia request" do
      klass = Class.new(action_class) do
        def handle(_request, _response)
          inertia_location("https://example.com")
        end
      end

      status, headers, = call_action(klass, headers: { "HTTP_X_INERTIA" => "true" })

      expect(headers["X-Inertia-Location"]).to eq("https://example.com")
      expect(status).to eq(409)
    end

    it "performs a normal redirect for a non-Inertia request" do
      klass = Class.new(action_class) do
        def handle(_request, _response)
          inertia_location("https://example.com")
        end
      end

      status, headers, = call_action(klass)

      expect(headers["Location"]).to eq("https://example.com")
      expect(status).to eq(302)
      expect(headers["X-Inertia-Location"]).to be_nil
    end
  end
end
