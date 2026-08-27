# frozen_string_literal: true

SSRRendererSpecFakeSSRConfig = Struct.new(:url, :raise_on_error)
SSRRendererSpecFakeConfig = Struct.new(:ssr)

RSpec.describe InertiaHanami::SSRRenderer do
  def build(raise_on_error: false)
    config = SSRRendererSpecFakeConfig.new(SSRRendererSpecFakeSSRConfig.new("http://localhost:13714", raise_on_error))
    described_class.new(config:)
  end

  def fake_http_success(body)
    response = Net::HTTPOK.new("1.1", "200", "OK")
    allow(response).to receive(:body).and_return(body)
    response
  end

  def fake_http_failure
    Net::HTTPInternalServerError.new("1.1", "500", "Internal Server Error")
  end

  let(:page) { { "component" => "Users/Show", "props" => { "name" => "Ada" } } }

  describe "#call" do
    it "POSTs the page JSON and returns the parsed head/body result" do
      body = { "head" => "<title>Ada</title>", "body" => "<div>Ada</div>" }.to_json
      allow(Net::HTTP).to receive(:post).and_return(fake_http_success(body))

      result = build.call(page)

      expect(result.head).to eq("<title>Ada</title>")
      expect(result.body).to eq("<div>Ada</div>")
    end

    it "joins an array head response into a single string" do
      body = { "head" => ["<title>Ada</title>", "<meta name=\"x\">"], "body" => "<div>Ada</div>" }.to_json
      allow(Net::HTTP).to receive(:post).and_return(fake_http_success(body))

      result = build.call(page)

      expect(result.head).to eq("<title>Ada</title>\n<meta name=\"x\">")
    end

    it "posts to the configured ssr url's /render endpoint" do
      body = { "head" => "", "body" => "" }.to_json
      allow(Net::HTTP).to receive(:post).and_return(fake_http_success(body))

      build.call(page)

      expect(Net::HTTP).to have_received(:post).with(
        URI("http://localhost:13714/render"), page.to_json, "Content-Type" => "application/json"
      )
    end

    it "caches by content digest, skipping a second HTTP call for the same page" do
      body = { "head" => "", "body" => "" }.to_json
      allow(Net::HTTP).to receive(:post).and_return(fake_http_success(body))

      renderer = build
      renderer.call(page)
      renderer.call(page)

      expect(Net::HTTP).to have_received(:post).once
    end

    it "issues a new HTTP call for a different page" do
      body = { "head" => "", "body" => "" }.to_json
      allow(Net::HTTP).to receive(:post).and_return(fake_http_success(body))

      renderer = build
      renderer.call(page)
      renderer.call(page.merge("props" => { "name" => "Grace" }))

      expect(Net::HTTP).to have_received(:post).twice
    end

    context "when the SSR server errors" do
      it "returns nil instead of raising when ssr.raise_on_error is false" do
        allow(Net::HTTP).to receive(:post).and_return(fake_http_failure)

        expect(build(raise_on_error: false).call(page)).to be_nil
      end

      it "re-raises when ssr.raise_on_error is true" do
        allow(Net::HTTP).to receive(:post).and_return(fake_http_failure)

        expect { build(raise_on_error: true).call(page) }.to raise_error(/responded with 500/)
      end

      it "returns nil on a connection error when ssr.raise_on_error is false" do
        allow(Net::HTTP).to receive(:post).and_raise(SocketError, "connection refused")

        expect(build(raise_on_error: false).call(page)).to be_nil
      end
    end
  end
end
