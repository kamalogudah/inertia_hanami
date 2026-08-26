# frozen_string_literal: true

RSpec.describe InertiaHanami::PropEvaluator do
  let(:action_class) do
    Class.new do
      def greeting
        "hello from action"
      end
    end
  end
  let(:action) { action_class.new }
  let(:evaluator) { described_class.new(action) }

  it "returns plain values unchanged" do
    expect(evaluator.evaluate("hello")).to eq("hello")
    expect(evaluator.evaluate(42)).to eq(42)
    expect(evaluator.evaluate(nil)).to be_nil
  end

  it "instance_execs a bare Proc against the action" do
    prop = -> { greeting }

    expect(evaluator.evaluate(prop)).to eq("hello from action")
  end

  it "instance_execs a Props::Base wrapper's block against the action" do
    prop = InertiaHanami::Props::Optional.new(block: -> { greeting })

    expect(evaluator.evaluate(prop).resolve).to eq("hello from action")
  end

  it "recursively evaluates hashes" do
    props = {
      static: "value",
      dynamic: -> { greeting },
      wrapped: InertiaHanami::Props::Optional.new(block: -> { greeting })
    }

    result = evaluator.evaluate(props)

    expect(result[:static]).to eq("value")
    expect(result[:dynamic]).to eq("hello from action")
    expect(result[:wrapped].resolve).to eq("hello from action")
  end

  it "recursively evaluates a wrapper block that itself returns a Proc/wrapper/hash" do
    nested_proc = InertiaHanami::Props::Optional.new(block: -> { -> { greeting } })
    nested_hash = InertiaHanami::Props::Optional.new(block: -> { { inner: -> { greeting } } })

    expect(evaluator.evaluate(nested_proc).resolve).to eq("hello from action")
    expect(evaluator.evaluate(nested_hash).resolve).to eq({ inner: "hello from action" })
  end

  describe "wrapper metadata" do
    it "preserves Defer#group after evaluation" do
      prop = InertiaHanami::Props::Defer.new(group: "stats", block: -> { greeting })

      expect(evaluator.evaluate(prop).group).to eq("stats")
    end

    it "preserves Merge#deep_merge and #match_on after evaluation" do
      prop = InertiaHanami::Props::Merge.new(deep_merge: true, match_on: "id", block: -> { greeting })

      result = evaluator.evaluate(prop)

      expect(result.deep_merge).to be(true)
      expect(result.match_on).to eq("id")
    end

    it "preserves Once#key, #fresh, and #expires_in after evaluation" do
      prop = InertiaHanami::Props::Once.new(key: "k", fresh: true, expires_in: 60, block: -> { greeting })

      result = evaluator.evaluate(prop)

      expect(result.key).to eq("k")
      expect(result.fresh).to be(true)
      expect(result.expires_in).to eq(60)
    end
  end
end
