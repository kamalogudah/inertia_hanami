# frozen_string_literal: true

require "inertia_hanami/middleware/csrf"
require "rack/mock_request"
require "hanami/action"
require "hanami/action/csrf_protection"

RSpec.describe InertiaHanami::Middleware::Csrf do
  let(:downstream_status) { 200 }
  let(:downstream_headers) { {} }
  let(:downstream_body) { [""] }
  let(:session) { nil }
  let(:downstream) do
    lambda do |env|
      env["rack.session"] = session if session
      [downstream_status, downstream_headers, downstream_body]
    end
  end
  let(:middleware) { described_class.new(downstream) }

  def call(headers: {}, path: "/")
    env = Rack::MockRequest.env_for(path, headers)
    middleware.call(env)
  end

  describe "incoming X-XSRF-TOKEN" do
    it "bridges it to X-CSRF-Token for downstream code" do
      seen_env = nil
      allow(downstream).to receive(:call).and_wrap_original do |original, env|
        seen_env = env
        original.call(env)
      end

      call(headers: { "HTTP_X_XSRF_TOKEN" => "the-token" })

      expect(seen_env["HTTP_X_CSRF_TOKEN"]).to eq("the-token")
    end

    it "does not overwrite an already-present X-CSRF-Token header" do
      seen_env = nil
      allow(downstream).to receive(:call).and_wrap_original do |original, env|
        seen_env = env
        original.call(env)
      end

      call(headers: { "HTTP_X_XSRF_TOKEN" => "from-cookie", "HTTP_X_CSRF_TOKEN" => "explicit" })

      expect(seen_env["HTTP_X_CSRF_TOKEN"]).to eq("explicit")
    end

    it "leaves X-CSRF-Token unset when no X-XSRF-TOKEN header is present" do
      seen_env = nil
      allow(downstream).to receive(:call).and_wrap_original do |original, env|
        seen_env = env
        original.call(env)
      end

      call

      expect(seen_env["HTTP_X_CSRF_TOKEN"]).to be_nil
    end
  end

  describe "outgoing XSRF-TOKEN cookie" do
    context "when the session has a CSRF token" do
      let(:session) { { "_csrf_token" => "session-token" } }

      it "sets a readable XSRF-TOKEN cookie mirroring the session token" do
        _status, headers, = call

        expect(headers["set-cookie"]).to include("XSRF-TOKEN=session-token")
      end

      it "does not mark the cookie HttpOnly, since the client needs to read it" do
        _status, headers, = call

        expect(headers["set-cookie"]).not_to include("HttpOnly")
      end
    end

    context "when there's no session" do
      let(:session) { nil }

      it "does not set a cookie" do
        _status, headers, = call

        expect(headers["set-cookie"]).to be_nil
      end
    end

    context "when the session has no CSRF token" do
      let(:session) { {} }

      it "does not set a cookie" do
        _status, headers, = call

        expect(headers["set-cookie"]).to be_nil
      end
    end
  end

  describe "end-to-end against a real Hanami::Action::CSRFProtection action" do
    # Hanami::Action::CSRFProtection skips wiring its before-hooks entirely
    # when Hanami.env?(:test) is true (see hanami-action's
    # CSRFProtection.included), which is always the case for this repo's
    # own test suite. Stub it false for the class definitions below so the
    # protection is actually active, proving the middleware bridges a real
    # verify_csrf_token check rather than just shuffling headers/cookies.
    let(:action_class) do
      allow(Hanami).to receive(:env?).with(:test).and_return(false)

      Class.new(Hanami::Action) do
        include Hanami::Action::CSRFProtection

        def handle(_req, res)
          res.body = "ok"
        end
      end
    end

    let(:session) { {} }
    let(:app) do
      klass = action_class
      lambda do |env|
        env["rack.session"] = session
        klass.new.call(env)
      end
    end
    let(:middleware) { described_class.new(app) }

    def get(headers: {})
      env = Rack::MockRequest.env_for("/", { "REQUEST_METHOD" => "GET" }.merge(headers))
      middleware.call(env)
    end

    def post(headers: {})
      env = Rack::MockRequest.env_for("/", { "REQUEST_METHOD" => "POST" }.merge(headers))
      middleware.call(env)
    end

    it "mints a session CSRF token and exposes it as a cookie on the initial GET" do
      _status, headers, = get

      expect(session["_csrf_token"]).to be_a(String)
      expect(headers["set-cookie"]).to include("XSRF-TOKEN=#{session["_csrf_token"]}")
    end

    it "rejects a POST that doesn't replay the token at all" do
      get

      expect { post }.to raise_error(Hanami::Action::InvalidCSRFTokenError)
    end

    it "accepts a POST that replays the minted token as X-XSRF-TOKEN, Inertia-client-style" do
      get
      token = session["_csrf_token"]

      status, = post(headers: { "HTTP_X_XSRF_TOKEN" => token })

      expect(status).to eq(200)
    end
  end
end
