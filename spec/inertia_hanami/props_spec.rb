# frozen_string_literal: true

RSpec.describe InertiaHanami::Props do
  it "resolves Optional, Always, Defer, Once, and Merge props by calling their block" do
    [
      InertiaHanami::Props::Optional,
      InertiaHanami::Props::Always,
      InertiaHanami::Props::Defer,
      InertiaHanami::Props::Once,
      InertiaHanami::Props::Merge
    ].each do |klass|
      prop = klass.new(block: -> { "value" })

      expect(prop.resolve).to eq("value")
    end
  end

  describe InertiaHanami::Props::Defer do
    it "defaults group to 'default', overridable per instance" do
      expect(described_class.new(block: -> {}).group).to eq("default")
      expect(described_class.new(group: "stats", block: -> {}).group).to eq("stats")
    end
  end

  describe InertiaHanami::Props::Once do
    it "defaults key, fresh, and expires_in" do
      prop = described_class.new(block: -> {})

      expect(prop.key).to be_nil
      expect(prop.fresh).to be(false)
      expect(prop.expires_in).to be_nil
    end

    describe "#expires_at" do
      it "returns nil when expires_in is nil" do
        expect(described_class.new(block: -> {}).expires_at).to be_nil
      end

      it "returns a millisecond timestamp when expires_in is set" do
        now = Time.utc(2026, 1, 1, 12, 0, 0)
        allow(Time).to receive(:now).and_return(now)

        prop = described_class.new(expires_in: 60, block: -> {})

        expect(prop.expires_at).to eq(((now + 60).to_f * 1_000).to_i)
      end
    end
  end

  describe InertiaHanami::Props::Merge do
    it "defaults deep_merge to false and match_on to nil" do
      prop = described_class.new(block: -> {})

      expect(prop.deep_merge).to be(false)
      expect(prop.match_on).to be_nil
    end
  end

  it "gives prop wrappers structural equality" do
    block = -> { "value" }

    expect(InertiaHanami::Props::Once.new(block:)).to eq(InertiaHanami::Props::Once.new(block:))
  end
end
