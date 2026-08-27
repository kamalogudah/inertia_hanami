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

  describe "encrypted history" do
    it "defaults encryptHistory/clearHistory to false when nothing is configured" do
      klass = Class.new(action_class) do
        def handle(_request, _response)
          inertia_render("Users/Show", props: {})
        end
      end

      _status, _headers, body = call_action(klass, headers: { "HTTP_X_INERTIA" => "true" })
      page = JSON.parse(body)

      expect(page["encryptHistory"]).to be(false)
      expect(page["clearHistory"]).to be(false)
    end

    it "falls back to the global inertia.config encrypt_history default" do
      Hanami.app["inertia.config"].encrypt_history = true

      klass = Class.new(action_class) do
        def handle(_request, _response)
          inertia_render("Users/Show", props: {})
        end
      end

      _status, _headers, body = call_action(klass, headers: { "HTTP_X_INERTIA" => "true" })
      page = JSON.parse(body)

      expect(page["encryptHistory"]).to be(true)
    ensure
      Hanami.app["inertia.config"].encrypt_history = false
    end

    it "uses the class-level encrypt_history macro, inherited by subclasses" do
      klass = Class.new(action_class) do
        encrypt_history

        def handle(_request, _response)
          inertia_render("Users/Show", props: {})
        end
      end
      subclass = Class.new(klass)

      _status, _headers, body = call_action(subclass, headers: { "HTTP_X_INERTIA" => "true" })
      page = JSON.parse(body)

      expect(page["encryptHistory"]).to be(true)
    end

    it "lets an instance-level encrypt_history call override the class default" do
      klass = Class.new(action_class) do
        encrypt_history

        def handle(_request, _response)
          encrypt_history(value: false)
          inertia_render("Users/Show", props: {})
        end
      end

      _status, _headers, body = call_action(klass, headers: { "HTTP_X_INERTIA" => "true" })
      page = JSON.parse(body)

      expect(page["encryptHistory"]).to be(false)
    end

    it "lets an instance-level clear_history call mark clearHistory true" do
      klass = Class.new(action_class) do
        def handle(_request, _response)
          clear_history
          inertia_render("Users/Show", props: {})
        end
      end

      _status, _headers, body = call_action(klass, headers: { "HTTP_X_INERTIA" => "true" })
      page = JSON.parse(body)

      expect(page["clearHistory"]).to be(true)
    end

    it "lets explicit inertia_render kwargs win over class/instance/config defaults" do
      Hanami.app["inertia.config"].encrypt_history = true

      klass = Class.new(action_class) do
        encrypt_history

        def handle(_request, _response)
          clear_history
          inertia_render("Users/Show", props: {}, encrypt_history: false, clear_history: false)
        end
      end

      _status, _headers, body = call_action(klass, headers: { "HTTP_X_INERTIA" => "true" })
      page = JSON.parse(body)

      expect(page["encryptHistory"]).to be(false)
      expect(page["clearHistory"]).to be(false)
    ensure
      Hanami.app["inertia.config"].encrypt_history = false
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

  describe "errors/flash props" do
    let(:session_action_class) do
      Class.new(Hanami::Action) do
        include Hanami::Action::Session
        include InertiaHanami::Action
      end
    end

    def call_session_action(klass, session: {})
      env = Rack::MockRequest.env_for("/users/1", "HTTP_X_INERTIA" => "true", "rack.session" => session)
      action = klass.new
      response = action.call(env)
      body = +""
      response.each { |part| body << part }
      [response.status, response.headers, body]
    end

    it "omits errors and flash entirely when the action has no session support" do
      klass = Class.new(action_class) do
        def handle(_request, _response)
          inertia_render("Users/Show", props: {})
        end
      end

      _status, _headers, body = call_action(klass, headers: { "HTTP_X_INERTIA" => "true" })
      page = JSON.parse(body)

      expect(page["props"]).not_to have_key("errors")
      expect(page["props"]).not_to have_key("flash")
    end

    it "shares errors stashed via share_inertia_errors, wrapped so partial reloads keep them" do
      klass = Class.new(session_action_class) do
        def handle(_request, _response)
          share_inertia_errors(name: ["is required"])
          inertia_render("Users/Show", props: {})
        end
      end

      _status, _headers, body = call_session_action(klass)
      page = JSON.parse(body)

      expect(page["props"]["errors"]).to eq("name" => ["is required"])
    end

    it "accepts an object responding to #to_h for share_inertia_errors" do
      errors_object = Class.new do
        def to_h = { base: ["invalid"] }
      end.new

      klass = Class.new(session_action_class) do
        define_method(:handle) do |_request, _response|
          share_inertia_errors(errors_object)
          inertia_render("Users/Show", props: {})
        end
      end

      _status, _headers, body = call_session_action(klass)
      page = JSON.parse(body)

      expect(page["props"]["errors"]).to eq("base" => ["invalid"])
    end

    it "omits the errors key when nothing was stashed and always_include_errors_hash is false" do
      klass = Class.new(session_action_class) do
        def handle(_request, _response)
          inertia_render("Users/Show", props: {})
        end
      end

      _status, _headers, body = call_session_action(klass)
      page = JSON.parse(body)

      expect(page["props"]).not_to have_key("errors")
    end

    it "shares an empty errors hash when nothing was stashed and always_include_errors_hash is true" do
      Hanami.app["inertia.config"].always_include_errors_hash = true

      klass = Class.new(session_action_class) do
        def handle(_request, _response)
          inertia_render("Users/Show", props: {})
        end
      end

      _status, _headers, body = call_session_action(klass)
      page = JSON.parse(body)

      expect(page["props"]["errors"]).to eq({})
    ensure
      Hanami.app["inertia.config"].always_include_errors_hash = false
    end

    it "shares the current flash when present" do
      klass = Class.new(session_action_class) do
        def handle(_request, _response)
          inertia_render("Users/Show", props: {})
        end
      end

      session = { Hanami::Action::Flash::KEY => { notice: "Saved!" } }
      _status, _headers, body = call_session_action(klass, session: session)
      page = JSON.parse(body)

      expect(page["props"]["flash"]).to eq("notice" => "Saved!")
    end

    it "omits flash when there is none" do
      klass = Class.new(session_action_class) do
        def handle(_request, _response)
          inertia_render("Users/Show", props: {})
        end
      end

      _status, _headers, body = call_session_action(klass)
      page = JSON.parse(body)

      expect(page["props"]).not_to have_key("flash")
    end
  end
end
