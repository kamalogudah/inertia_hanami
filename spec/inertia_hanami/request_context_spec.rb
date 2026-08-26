# frozen_string_literal: true

RSpec.describe InertiaHanami::RequestContext do
  def build(env)
    described_class.new(env)
  end

  describe "#inertia?" do
    it "is true when X-Inertia is 'true'" do
      expect(build("HTTP_X_INERTIA" => "true")).to be_inertia
    end

    it "is false when the header is absent" do
      expect(build({})).not_to be_inertia
    end

    it "is false for any other value" do
      expect(build("HTTP_X_INERTIA" => "false")).not_to be_inertia
    end
  end

  describe "#version" do
    it "returns the header value when present" do
      expect(build("HTTP_X_INERTIA_VERSION" => "abc123").version).to eq("abc123")
    end

    it "returns nil when absent" do
      expect(build({}).version).to be_nil
    end
  end

  describe "#partial_component / #partial?" do
    it "returns the component name and reports partial? true" do
      context = build("HTTP_X_INERTIA_PARTIAL_COMPONENT" => "Users/Show")

      expect(context.partial_component).to eq("Users/Show")
      expect(context).to be_partial
    end

    it "reports partial? false when absent" do
      context = build({})

      expect(context.partial_component).to be_nil
      expect(context).not_to be_partial
    end
  end

  describe "comma-separated headers" do
    it "splits and trims X-Inertia-Partial-Data into #partial_only" do
      context = build("HTTP_X_INERTIA_PARTIAL_DATA" => "user.name, user.email ,stats")

      expect(context.partial_only).to eq(%w[user.name user.email stats])
    end

    it "splits X-Inertia-Partial-Except into #partial_except" do
      context = build("HTTP_X_INERTIA_PARTIAL_EXCEPT" => "user.secret,other")

      expect(context.partial_except).to eq(%w[user.secret other])
    end

    it "splits X-Inertia-Reset into #reset" do
      context = build("HTTP_X_INERTIA_RESET" => "token")

      expect(context.reset).to eq(["token"])
    end

    it "returns [] when the header is absent" do
      expect(build({}).partial_only).to eq([])
      expect(build({}).partial_except).to eq([])
      expect(build({}).reset).to eq([])
    end

    it "returns [] when the header is an empty string" do
      expect(build("HTTP_X_INERTIA_PARTIAL_DATA" => "").partial_only).to eq([])
    end

    it "drops empty segments from stray commas" do
      expect(build("HTTP_X_INERTIA_PARTIAL_DATA" => "name,,email").partial_only).to eq(%w[name email])
    end
  end

  describe "#partial_params" do
    it "bundles the partial-reload fields under the keys ProtocolBuilder expects" do
      context = build(
        "HTTP_X_INERTIA_PARTIAL_COMPONENT" => "Users/Show",
        "HTTP_X_INERTIA_PARTIAL_DATA" => "user.name",
        "HTTP_X_INERTIA_PARTIAL_EXCEPT" => "user.secret",
        "HTTP_X_INERTIA_RESET" => "token"
      )

      expect(context.partial_params).to eq(
        component: "Users/Show",
        only: ["user.name"],
        except: ["user.secret"],
        reset: ["token"]
      )
    end

    it "plugs directly into ProtocolBuilder's partial: keyword" do
      context = build(
        "HTTP_X_INERTIA_PARTIAL_COMPONENT" => "Users/Show",
        "HTTP_X_INERTIA_PARTIAL_DATA" => "user.name"
      )
      props = { user: { name: "Ada", email: "ada@example.com" } }

      result = InertiaHanami::ProtocolBuilder.new(
        component: "Users/Show",
        props:,
        partial: context.partial_params
      ).call

      expect(result[:props]).to eq(user: { name: "Ada" })
    end
  end
end
