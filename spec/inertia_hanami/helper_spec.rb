# frozen_string_literal: true

RSpec.describe InertiaHanami::Helper do
  let(:page) { { "component" => "Users/Show", "props" => { "name" => "Ada" }, "url" => "/users/1" } }

  describe "#inertia_root" do
    it "renders a script tag with the raw page JSON and a div mount point, both using the default id" do
      html = described_class.inertia_root(page:)

      expect(html).to eq(<<~HTML)
        <script data-page="app" type="application/json">#{page.to_json}</script>
        <div id="app"></div>
      HTML
    end

    it "honors an explicit id override" do
      html = described_class.inertia_root(page:, id: "custom-root")

      expect(html).to start_with(%(<script data-page="custom-root" type="application/json">))
      expect(html).to include(%(<div id="custom-root"></div>))
    end

    it "escapes a literal </script sequence in the page JSON so it can't close the tag early" do
      unsafe_page = { "props" => { "bio" => "</script><script>alert(1)</script>" } }

      html = described_class.inertia_root(page: unsafe_page)

      expect(html).not_to include("</script><script>alert(1)</script>")

      script_json = html[/<script data-page="app" type="application\/json">(.*?)<\/script>/m, 1]
      expect(JSON.parse(script_json).dig("props", "bio")).to eq("</script><script>alert(1)</script>")
    end

    it "falls back to Hanami.app[\"inertia.config\"].root_dom_id when no id is given" do
      allow(Hanami.app["inertia.config"]).to receive(:root_dom_id).and_return("custom-app")

      html = described_class.inertia_root(page:)

      expect(html).to start_with(%(<script data-page="custom-app" type="application/json">))
      expect(html).to include(%(<div id="custom-app"></div>))
    end
  end
end
