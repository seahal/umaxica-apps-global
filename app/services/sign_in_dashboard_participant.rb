# typed: false
# frozen_string_literal: true

class SignInDashboardParticipant
  def initialize(cycle:, actor:, evaluators: [])
    @cycle = cycle
    @actor = actor
    @evaluators = evaluators
  end

  def evaluate
    SignInParticipantResult.new(
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
    return item if item.is_a?(SignInParticipantItem)

    raise ArgumentError, "dashboard evaluator must return SignInParticipantItem"
  end
end
