# frozen_string_literal: true

RSpec.describe InertiaHanami::Helper do
  let(:page) { { "component" => "Users/Show", "props" => { "name" => "Ada" }, "url" => "/users/1" } }

  describe "#inertia_root" do
    it "renders a div with the default id from the inertia config and the page JSON-encoded" do
      html = described_class.inertia_root(page:)

      expect(html).to eq(%(<div id="app" data-page="#{CGI.escapeHTML(page.to_json)}"></div>))
    end

    it "honors an explicit id override" do
      html = described_class.inertia_root(page:, id: "custom-root")

      expect(html).to start_with(%(<div id="custom-root" data-page="))
    end

    it "HTML-escapes characters in the page JSON that would break out of the attribute" do
      unsafe_page = { "props" => { "bio" => %("><script>alert(1)</script>) } }

      html = described_class.inertia_root(page: unsafe_page)

      expect(html).not_to include('"><script>')
      expect(html).to include("&lt;script&gt;")
    end

    it "falls back to Hanami.app[\"inertia.config\"].root_dom_id when no id is given" do
      allow(Hanami.app["inertia.config"]).to receive(:root_dom_id).and_return("custom-app")

      html = described_class.inertia_root(page:)

      expect(html).to start_with(%(<div id="custom-app" data-page="))
    end
  end
end
