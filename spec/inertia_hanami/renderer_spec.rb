# frozen_string_literal: true

RendererSpecFakeRequest = Struct.new(:env, :fullpath)

class RendererSpecFakeResponse
  attr_accessor :format, :body
  attr_reader :headers, :exposures

  def initialize
    @headers = {}
    @exposures = {}
  end

  def []=(key, value)
    @exposures[key] = value
  end

  def [](key)
    @exposures[key]
  end
end

RSpec.describe InertiaHanami::Renderer do
  def build(env: {}, **opts)
    request = RendererSpecFakeRequest.new(env, "/users/1")
    response = RendererSpecFakeResponse.new

    renderer = described_class.new(request:, response:, **opts)
    renderer.render

    [request, response]
  end

  describe "on an Inertia XHR request (X-Inertia: true)" do
    it "sets the X-Inertia response header, JSON format, and a JSON-encoded body" do
      _, response = build(env: { "HTTP_X_INERTIA" => "true" }, component: "Users/Show", props: { name: "Ada" })

      expect(response.headers["X-Inertia"]).to eq("true")
      expect(response.format).to eq(:json)

      page = JSON.parse(response.body)
      expect(page).to eq(
        "component" => "Users/Show",
        "props" => { "name" => "Ada" },
        "url" => "/users/1",
        "version" => nil,
        "encryptHistory" => false,
        "clearHistory" => false
      )
    end

    it "includes deferredProps/mergeProps/matchPropsOn metadata only when relevant props are present" do
      props = {
        stats: InertiaHanami::Props::Defer.new(group: "charts", block: -> { "stats" }),
        comments: InertiaHanami::Props::Merge.new(match_on: "id", block: -> { [1, 2] })
      }

      _, response = build(env: { "HTTP_X_INERTIA" => "true" }, component: "Users/Show", props:)

      page = JSON.parse(response.body)
      expect(page["deferredProps"]).to eq("charts" => ["stats"])
      expect(page["mergeProps"]).to eq(["comments"])
      expect(page["matchPropsOn"]).to eq(["comments.id"])
    end

    it "includes prependProps/scrollProps for a Scroll prop, per the merge-intent header" do
      props = { comments: InertiaHanami::Props::Scroll.new(current_page: 1, next_page: 2, block: -> { [1, 2] }) }
      env = { "HTTP_X_INERTIA" => "true", "HTTP_X_INERTIA_INFINITE_SCROLL_MERGE_INTENT" => "prepend" }

      _, response = build(env:, component: "Users/Show", props:)

      page = JSON.parse(response.body)
      expect(page["mergeProps"]).to be_nil
      expect(page["prependProps"]).to eq(["comments"])
      expect(page["scrollProps"]).to eq(
        "comments" => { "pageName" => "page", "previousPage" => nil, "nextPage" => 2, "currentPage" => 1,
                        "reset" => false }
      )
    end

    it "passes the version and history flags through to the envelope" do
      _, response = build(
        env: { "HTTP_X_INERTIA" => "true" },
        component: "Users/Show",
        props: {},
        version: "abc123",
        encrypt_history: true,
        clear_history: true
      )

      page = JSON.parse(response.body)
      expect(page["version"]).to eq("abc123")
      expect(page["encryptHistory"]).to be true
      expect(page["clearHistory"]).to be true
    end

    it "uses the given url instead of the request's fullpath when provided" do
      _, response = build(env: { "HTTP_X_INERTIA" => "true" }, component: "Users/Show", props: {}, url: "/custom")

      page = JSON.parse(response.body)
      expect(page["url"]).to eq("/custom")
    end

    it "applies partial-reload headers via ProtocolBuilder" do
      props = { user: { name: "Ada", email: "ada@example.com" } }
      env = {
        "HTTP_X_INERTIA" => "true",
        "HTTP_X_INERTIA_PARTIAL_COMPONENT" => "Users/Show",
        "HTTP_X_INERTIA_PARTIAL_DATA" => "user.name"
      }

      _, response = build(env:, component: "Users/Show", props:)

      page = JSON.parse(response.body)
      expect(page["props"]).to eq("user" => { "name" => "Ada" })
    end
  end

  describe "on an initial full-page load (no X-Inertia header)" do
    it "does not touch the response format/body/X-Inertia header" do
      _, response = build(component: "Users/Show", props: { name: "Ada" })

      expect(response.headers["X-Inertia"]).to be_nil
      expect(response.format).to be_nil
      expect(response.body).to be_nil
    end

    it "exposes the page envelope as a plain Hash under :page" do
      _, response = build(component: "Users/Show", props: { name: "Ada" })

      expect(response[:page]).to eq(
        "component" => "Users/Show",
        "props" => { name: "Ada" },
        "url" => "/users/1",
        "version" => nil,
        "encryptHistory" => false,
        "clearHistory" => false
      )
    end

    context "when SSR is enabled" do
      before do
        allow(Hanami.app["inertia.config"].ssr).to receive(:enabled).and_return(true)
      end

      it "exposes ssr_head/ssr_body instead of :page when the SSR renderer succeeds" do
        result = InertiaHanami::SSRRenderer::Result.new("<title>Ada</title>", "<div>Ada</div>")
        allow(InertiaHanami::SSRRenderer.instance).to receive(:call).and_return(result)

        _, response = build(component: "Users/Show", props: { name: "Ada" })

        expect(response[:ssr_head]).to eq("<title>Ada</title>")
        expect(response[:ssr_body]).to eq("<div>Ada</div>")
        expect(response[:page]).to be_nil
      end

      it "falls back to exposing :page when the SSR renderer returns nil" do
        allow(InertiaHanami::SSRRenderer.instance).to receive(:call).and_return(nil)

        _, response = build(component: "Users/Show", props: { name: "Ada" })

        expect(response[:page]).to eq(
          "component" => "Users/Show",
          "props" => { name: "Ada" },
          "url" => "/users/1",
          "version" => nil,
          "encryptHistory" => false,
          "clearHistory" => false
        )
        expect(response[:ssr_head]).to be_nil
        expect(response[:ssr_body]).to be_nil
      end
    end
  end
end
