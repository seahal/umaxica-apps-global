# typed: false
# frozen_string_literal: true

module SignIn
  class GuardrailParticipant
    GENERIC_MESSAGE = I18n.t("errors.messages.not_authorized")

    DEFAULT_EVALUATORS = [
      :actor_login_allowed_item,
      :existing_restricted_session_item,
    ].freeze

    def initialize(cycle:, actor:, evaluators: DEFAULT_EVALUATORS)
      @cycle = cycle
      @actor = actor
      @evaluators = evaluators
    end

    def evaluate
      ParticipantResult.new(
        participant: :guardrail,
        stack: stack,
        next_status: "CHECKPOINT_PENDING",
        message: GENERIC_MESSAGE,
      )
    end

    def advance_if_clear!
      cycle.class.transaction do
        cycle.lock!
        result = evaluate
        return result if result.blocking?

        cycle.advance_sign_in_to_checkpoint!
        result
      end
    end

    private

    attr_reader :cycle, :actor, :evaluators

    def stack
      evaluators.filter_map do |evaluator|
        item = evaluator.respond_to?(:call) ? evaluator.call(cycle: cycle, actor: actor) : send(evaluator)
        normalize_item(item)
      end
    end

    def actor_login_allowed_item
      return nil unless actor.respond_to?(:login_allowed?)
      return nil if actor.login_allowed?

      blocking_item(:actor_login_not_allowed)
    end

    def existing_restricted_session_item
      return nil unless actor

      metadata = surface_metadata
      return nil unless metadata

      token_class = metadata.fetch(:token_class)
      foreign_key = metadata.fetch(:foreign_key)
      return nil unless token_class.restricted_status.exists?(foreign_key => actor.id)

      blocking_item(:restricted_session_exists)
    end

    def surface_metadata
      SignIn::SessionLimitManager::SURFACES[cycle.class]
    end

    def blocking_item(key)
      ParticipantItem.new(key: key, blocking: true, cleared: false, message: GENERIC_MESSAGE)
    end

    def normalize_item(item)
      return nil if item.blank?
      return item if item.is_a?(ParticipantItem)

      raise ArgumentError, "guardrail evaluator must return SignIn::ParticipantItem"
    end
  end
end
