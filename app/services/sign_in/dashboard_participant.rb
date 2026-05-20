# typed: false
# frozen_string_literal: true

module SignIn
  class DashboardParticipant
    def initialize(cycle:, actor:, evaluators: [])
      @cycle = cycle
      @actor = actor
      @evaluators = evaluators
    end

    def evaluate
      ParticipantResult.new(
        participant: :dashboard,
        stack: stack,
        next_status: "RETURN_PENDING",
      )
    end

    def advance!
      cycle.class.transaction do
        cycle.lock!
        result = evaluate
        cycle.advance_sign_in_to_return!
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

      raise ArgumentError, "dashboard evaluator must return SignIn::ParticipantItem"
    end
  end
end
