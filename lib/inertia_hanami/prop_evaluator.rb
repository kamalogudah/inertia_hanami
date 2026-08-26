# frozen_string_literal: true

module InertiaHanami
  # Resolves a props structure (plain values, Procs, Props::Base wrappers, and
  # nested hashes thereof) against a Hanami action instance, so prop blocks can
  # access the action's params/session/deps via instance_exec.
  class PropEvaluator
    def initialize(action)
      @action = action
    end

    def evaluate(props)
      case props
      when Hash
        props.transform_values { |value| evaluate(value) }
      when Props::Base
        props.with(block: resolved_block(props.block))
      when Proc
        evaluate(@action.instance_exec(&props))
      else
        props
      end
    end

    private

    def resolved_block(block)
      value = evaluate(@action.instance_exec(&block))
      -> { value }
    end
  end
end
