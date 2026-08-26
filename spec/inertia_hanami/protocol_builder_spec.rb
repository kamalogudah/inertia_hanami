# frozen_string_literal: true

RSpec.describe InertiaHanami::ProtocolBuilder do
  def build(props, **partial)
    described_class.new(component: "Users/Show", props:, partial:).call
  end

  describe "full load (no partial headers)" do
    it "includes plain props and Always, excludes Optional and Defer" do
      props = {
        name: "Ada",
        secret: InertiaHanami::Props::Optional.new(block: -> { "hidden" }),
        stats: InertiaHanami::Props::Defer.new(block: -> { "stats" }),
        banner: InertiaHanami::Props::Always.new(block: -> { "always" })
      }

      result = build(props)

      expect(result[:props]).to eq(name: "Ada", banner: "always")
    end

    it "includes Once props and records them in onceProps" do
      props = { token: InertiaHanami::Props::Once.new(expires_in: 60, block: -> { "abc" }) }

      result = build(props)

      expect(result[:props]).to eq(token: "abc")
      expect(result[:onceProps]).to match("token" => { "expiresAt" => kind_of(Integer), "fresh" => false })
    end

    it "records Merge props in mergeProps/deepMergeProps/matchPropsOn" do
      props = {
        comments: InertiaHanami::Props::Merge.new(match_on: "id", block: -> { [1, 2] }),
        settings: InertiaHanami::Props::Merge.new(deep_merge: true, block: -> { { theme: "dark" } })
      }

      result = build(props)

      expect(result[:props]).to eq(comments: [1, 2], settings: { theme: "dark" })
      expect(result[:mergeProps]).to eq(["comments"])
      expect(result[:deepMergeProps]).to eq(["settings"])
      expect(result[:matchPropsOn]).to eq(["comments.id"])
    end

    it "records an unrequested Defer prop's path under its group" do
      props = { stats: InertiaHanami::Props::Defer.new(group: "charts", block: -> { "stats" }) }

      result = build(props)

      expect(result[:props]).to eq({})
      expect(result[:deferredProps]).to eq("charts" => ["stats"])
    end

    it "omits metadata keys entirely when there is nothing to report" do
      result = build({ name: "Ada" })

      expect(result).to eq(props: { name: "Ada" })
    end
  end

  describe "partial reload" do
    it "keeps only the requested dot-path and its ancestor nodes" do
      props = {
        user: { name: "Ada", email: "ada@example.com" },
        other: "dropped"
      }

      result = build(props, component: "Users/Show", only: ["user.name"])

      expect(result[:props]).to eq(user: { name: "Ada" })
    end

    it "drops paths matched by except, even nested ones" do
      props = { user: { name: "Ada", secret: "s3cr3t" }, other: "kept" }

      result = build(props, component: "Users/Show", except: ["user.secret"])

      expect(result[:props]).to eq(user: { name: "Ada" }, other: "kept")
    end

    it "ignores only/except when the partial component doesn't match" do
      props = { name: "Ada", other: "kept too" }

      result = build(props, component: "Users/Index", only: ["name"])

      expect(result[:props]).to eq(name: "Ada", other: "kept too")
    end

    it "includes Optional/Defer only when explicitly requested via only" do
      props = {
        secret: InertiaHanami::Props::Optional.new(block: -> { "hidden" }),
        stats: InertiaHanami::Props::Defer.new(block: -> { "stats" })
      }

      result = build(props, component: "Users/Show", only: %w[secret stats])

      expect(result[:props]).to eq(secret: "hidden", stats: "stats")
      expect(result[:deferredProps]).to be_nil
    end

    it "still reports Defer in deferredProps when not requested during a partial reload" do
      props = {
        name: "Ada",
        stats: InertiaHanami::Props::Defer.new(block: -> { "stats" })
      }

      result = build(props, component: "Users/Show", only: ["name"])

      expect(result[:props]).to eq(name: "Ada")
      expect(result[:deferredProps]).to eq("default" => ["stats"])
    end

    it "force-includes a Once prop named in reset even if it's in except_once" do
      props = { token: InertiaHanami::Props::Once.new(block: -> { "abc" }) }

      result = build(props, component: "Users/Show", reset: ["token"], except_once: ["token"])

      expect(result[:props]).to eq(token: "abc")
    end

    it "drops a Once prop named in except_once" do
      props = { token: InertiaHanami::Props::Once.new(block: -> { "abc" }) }

      result = build(props, component: "Users/Show", except_once: ["token"])

      expect(result[:props]).to eq({})
      expect(result[:onceProps]).to be_nil
    end

    it "prunes a plain nested hash down to its surviving children" do
      props = { user: { name: "Ada", email: "ada@example.com" }, other: "dropped" }

      result = build(props, component: "Users/Show", only: ["user.name"])

      expect(result[:props][:user]).to eq(name: "Ada")
      expect(result[:props]).not_to have_key(:other)
    end
  end
end
