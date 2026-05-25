# typed: false
# frozen_string_literal: true

module SignIn
  class CheckpointParticipant
    def initialize(cycle:, actor:, evaluators: [])
      @cycle = cycle
      @actor = actor
      @evaluators = evaluators
    end

    def evaluate
      ParticipantResult.new(
        participant: :checkpoint,
        stack: stack,
        next_status: "SELECTOR_PENDING",
      )
    end

    def advance_if_clear!
      cycle.class.transaction do
        cycle.lock!
        result = evaluate
        return result if result.blocking?

        cycle.advance_sign_in_to_selector!
        result
      end
    end

    private

    attr_reader :cycle, :actor, :evaluators

    def stack
      evaluators.filter_map do |evaluator|
        normalize_item(evaluator.call(cycle: cycle, actor: actor))
      end
    end

    def normalize_item(item)
      return nil if item.blank?
      return item if item.is_a?(ParticipantItem)

      raise ArgumentError, "checkpoint evaluator must return SignIn::ParticipantItem"
    end
  end
end
